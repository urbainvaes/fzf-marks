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
    echo "${mark_to_add}" | _color_marks
}

function _handle_symlinks {
    local fname
    if [ -L "${FZF_MARKS_FILE}" ]; then
        fname=$(readlink "${FZF_MARKS_FILE}")
    else
        fname=${FZF_MARKS_FILE}
    fi
    echo "${fname}"
}

function _color_marks {
    if [[ "${FZF_MARKS_NO_COLORS}" == "1" ]]; then
        cat
    else
        local esc c_lhs c_rhs c_colon
        esc=$(printf '\033')
        c_lhs=${FZF_MARKS_COLOR_LHS:-39}
        c_rhs=${FZF_MARKS_COLOR_RHS:-36}
        c_colon=${FZF_MARKS_COLOR_COLON:-33}
        sed "s/^\(.*\) : \(.*\)$/${esc}[${c_lhs}m\1${esc}[0m ${esc}[${c_colon}m:${esc}[0m ${esc}[${c_rhs}m\2${esc}[0m/"
    fi
}

function jump {
    local jumpline jumpdir bookmarks
    jumpline=$(_color_marks < "${FZF_MARKS_FILE}" | eval ${FZF_MARKS_COMMAND} --ansi --bind=ctrl-y:accept --query="$*" --select-1 --tac)
    if [[ -n ${jumpline} ]]; then
        jumpdir=$(echo "${jumpline}" | sed -n 's/.* : \(.*\)$/\1/p' | sed "s#~#${HOME}#")
        bookmarks=$(_handle_symlinks)
        perl -n -i -e "print unless /^${jumpline//\//\\/}\$/" "${bookmarks}"
        cd "${jumpdir}" && echo "${jumpline}" >> "${FZF_MARKS_FILE}"
    fi
}

function dmark {
    local marks_to_delete line bookmarks
    marks_to_delete=$(_color_marks < "${FZF_MARKS_FILE}" | eval ${FZF_MARKS_COMMAND} -m --ansi --bind=ctrl-y:accept,ctrl-t:toggle --query="$*" --tac)
    bookmarks=$(_handle_symlinks)

    if [[ -n ${marks_to_delete} ]]; then
        while IFS='' read -r line; do
            perl -n -i -e "print unless /^${line//\//\\/}\$/" "${bookmarks}"
        done <<< "$marks_to_delete"

        echo "** The following marks have been deleted **"
        echo "${marks_to_delete}" | _color_marks
    fi
}

bind "\"${FZF_MARKS_JUMP:-\C-g}\":\"jump\\n\""
if [ "${FZF_MARKS_DMARK}" ]; then
    bind "\"${FZF_MARKS_DMARK}\":\"dmark\\n\""
fi
