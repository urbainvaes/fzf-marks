# MIT License

# Copyright (c) 2018 Urbain Vaes

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

if [[ -z "${FZF_MARKS_FILE}" ]] ; then
    export FZF_MARKS_FILE="${HOME}/.fzf-marks"
fi

if [[ ! -f "${FZF_MARKS_FILE}" ]]; then
    touch "${FZF_MARKS_FILE}"
fi

if [[ -z "${FZF_MARKS_COMMAND}" ]] ; then

    FZF_VERSION=$(fzf --version | awk -F. '{ print $1 * 1e6 + $2 * 1e3 + $3 }')
    MINIMUM_VERSION=16001

    if [[ $FZF_VERSION -gt $MINIMUM_VERSION ]]; then
        FZF_MARKS_COMMAND="fzf --height 40% --reverse"
    elif [[ ${FZF_TMUX:-1} -eq 1 ]]; then
        FZF_MARKS_COMMAND="fzf-tmux -d${FZF_TMUX_HEIGHT:-40%}"
    else
        FZF_MARKS_COMMAND="fzf"
    fi

    export FZF_MARKS_COMMAND
fi

function fzm
{
  if [ -z "$1" ]; then
    _fzm_usage
    return
  fi

  subcommand="$1"
  shift

  case "$subcommand" in
    -n|--new)
      mark "$@"
      ;;
    -d|--delete)
      dmark "$@"
      ;;
    -j|--jump)
      jump "$@"
      ;;
    -h|--help)
      _fzm_usage
      ;;
    *)
      jump "$subcommand"
      ;;
  esac
  return $?
}

function _fzm_usage
{
  cat <<"EOB"
OPTIONS:
  -n, --new: add a mark to the current directory
    fzm -n|--new <mark>
  -d, --delete: delete a mark
    fzm -d|--delete [<mark>]
  -j, --jump: jump to a mark
    fzm -j|--jump [<mark>]
  -h, --help: print this help
    fzm -h|--help
EOB
}

function mark {
    local mark_to_add
    mark_to_add="$* : $(pwd)"

    if grep -qxFe "${mark_to_add}" "${FZF_MARKS_FILE}"; then
        echo "** The following mark already exists **"
    else
        echo "${mark_to_add}" >> "${FZF_MARKS_FILE}"
        echo "** The following mark has been added **"
    fi
    echo "${mark_to_add}"
}

function handle_symlinks {
    local fname
    if [ -L "${FZF_MARKS_FILE}" ]; then
        fname=$(readlink "${FZF_MARKS_FILE}")
    else
        fname=${FZF_MARKS_FILE}
    fi
    echo "${fname}"
}

# Ensure precmds are run after cd
function redraw-prompt() {
    local precmd
    for precmd in $precmd_functions; do
        $precmd
    done
    zle reset-prompt
}
zle -N redraw-prompt

function jump {
    local jumpline jumpdir bookmarks
    jumpline=$($(echo ${FZF_MARKS_COMMAND}) --bind=ctrl-y:accept --query="$*" --select-1 --tac < "${FZF_MARKS_FILE}")
    if [[ -n ${jumpline} ]]; then
        jumpdir=$(echo "${jumpline}" | sed -n 's/.* : \(.*\)$/\1/p' | sed "s#~#${HOME}#")
        bookmarks=$(handle_symlinks)
        perl -n -i -e "print unless /^${jumpline//\//\\/}\$/" "${bookmarks}"
        cd "${jumpdir}" && echo "${jumpline}" >> "${FZF_MARKS_FILE}"
    fi
    zle && zle redraw-prompt
}

function dmark {
    local marks_to_delete line bookmarks
    marks_to_delete=$($(echo ${FZF_MARKS_COMMAND}) -m --bind=ctrl-y:accept,ctrl-t:toggle --query="$*" --tac < "${FZF_MARKS_FILE}")
    bookmarks=$(handle_symlinks)

    if [[ -n ${marks_to_delete} ]]; then
        while IFS='' read -r line; do
            perl -n -i -e "print unless /^${line//\//\\/}\$/" "${bookmarks}"
        done <<< "$marks_to_delete"

        echo "** The following marks have been deleted **"
        echo "${marks_to_delete}"
    fi
    zle && zle reset-prompt
}

zle -N jump
zle -N dmark

bindkey ${FZF_MARKS_JUMP:-'^g'} jump
if [ "${FZF_MARKS_DMARK}" ]; then
    bindkey ${FZF_MARKS_DMARK} dmark
fi
