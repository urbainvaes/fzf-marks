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

command -v fzf >/dev/null 2>&1 || return

if [[ -z "${FZF_MARKS_FILE}" ]] ; then
    FZF_MARKS_FILE="${HOME}/.fzf-marks"
fi

if [[ ! -f "${FZF_MARKS_FILE}" ]]; then
    touch "${FZF_MARKS_FILE}"
fi

if [[ -z "${FZF_MARKS_COMMAND}" ]] ; then

    FZF_VERSION=$(fzf --version | awk -F. '{ print $1 * 1e6 + $2 * 1e3 + $3 }')
    MINIMUM_VERSION=16001

    if [[ $FZF_VERSION -gt $MINIMUM_VERSION ]]; then
        FZF_MARKS_COMMAND="fzf --height 40% --reverse --header='ctrl-y:jump, ctrl-t:toggle, ctrl-d:delete'"
    elif [[ ${FZF_TMUX:-1} -eq 1 ]]; then
        FZF_MARKS_COMMAND="fzf-tmux -d${FZF_TMUX_HEIGHT:-40%}"
    else
        FZF_MARKS_COMMAND="fzf"
    fi
fi

function setup_completion {
    complete -W "$(sed 's/\(.*\) : .*$/"\1"/' < "$FZF_MARKS_FILE")" fzm
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
    setup_completion
}

function _handle_symlinks {
    local fname link
    if [ -L "${FZF_MARKS_FILE}" ]; then
        link=$(readlink "${FZF_MARKS_FILE}")
        case "$link" in
          /*) fname="$link";;
          *) fname="$(dirname "$FZF_MARKS_FILE")/$link";;
        esac
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
        sed "s/^\\(.*\\) : \\(.*\\)$/${esc}[${c_lhs}m\\1${esc}[0m ${esc}[${c_colon}m:${esc}[0m ${esc}[${c_rhs}m\\2${esc}[0m/"
    fi
}

function fzm {
    lines=$(_color_marks < "${FZF_MARKS_FILE}" | eval ${FZF_MARKS_COMMAND} \
        --ansi \
        --expect="${FZF_MARKS_DELETE:-ctrl-d}" \
        --multi \
        --bind=ctrl-y:accept,ctrl-t:toggle \
        --query="\"$*\"" \
        --select-1 \
        --tac)
    if [[ -z "$lines" ]]; then
        return 1
    fi

    key=$(head -1 <<< "$lines")

    if [[ $key == "${FZF_MARKS_DELETE:-ctrl-d}" ]]; then
        dmark "-->-->-->" "$(sed 1d <<< "$lines")"
    else
        jump "-->-->-->" "$(tail -1 <<< "${lines}")"
    fi
}

function jump {
    local jumpline jumpdir bookmarks
    if [[ $1 == "-->-->-->" ]]; then
        jumpline=$2
    else
        jumpline=$(_color_marks < "${FZF_MARKS_FILE}" | eval ${FZF_MARKS_COMMAND} --ansi --bind=ctrl-y:accept --query="$*" --select-1 --tac)
    fi
    if [[ -n ${jumpline} ]]; then
        jumpdir=$(echo "${jumpline}" | sed 's/.*: \(.*\)$/\1/' | sed "s#^~#${HOME}#")
        bookmarks=$(_handle_symlinks)
        cd "${jumpdir}" || return
        if ! [[ "${FZF_MARKS_KEEP_ORDER}" == 1 ]]; then
            perl -n -i -e "print unless /^\\Q${jumpline//\//\\/}\\E\$/" "${bookmarks}"
            echo "${jumpline}" >> "${FZF_MARKS_FILE}"
        fi
    fi
}

function dmark {
    local marks_to_delete line bookmarks
    if [[ $1 == "-->-->-->" ]]; then
        marks_to_delete=$2
    else
        marks_to_delete=$(_color_marks < "${FZF_MARKS_FILE}" | eval ${FZF_MARKS_COMMAND} -m --ansi --bind=ctrl-y:accept,ctrl-t:toggle --query="$*" --tac)
    fi
    bookmarks=$(_handle_symlinks)

    if [[ -n ${marks_to_delete} ]]; then
        while IFS='' read -r line; do
            perl -n -i -e "print unless /^\\Q${line//\//\\/}\\E\$/" "${bookmarks}"
        done <<< "$marks_to_delete"

        [[ $(wc -l <<< "${marks_to_delete}") == 1 ]] \
            && echo "** The following mark has been deleted **" \
            || echo "** The following marks have been deleted **"
        echo "${marks_to_delete}" | _color_marks
    fi
    setup_completion
}

bind "\"${FZF_MARKS_JUMP:-\C-g}\":\"fzm\\n\""
if [ "${FZF_MARKS_DMARK}" ]; then
    bind "\"${FZF_MARKS_DMARK}\":\"dmark\\n\""
fi

setup_completion
