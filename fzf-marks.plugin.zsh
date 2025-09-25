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

if [[ -z ${FZF_MARKS_FILE-} ]] ; then
    FZF_MARKS_FILE=$HOME/.fzf-marks
fi

if [[ ! -f $FZF_MARKS_FILE ]]; then
    touch "$FZF_MARKS_FILE"
fi

if [[ -z ${FZF_MARKS_COMMAND-} ]] ; then

    _fzm_FZF_VERSION=$(fzf --version | awk -F. '{ print $1 * 1e6 + $2 * 1e3 + $3 }')
    _fzm_MINIMUM_VERSION=16001

    if [[ $_fzm_FZF_VERSION -gt $_fzm_MINIMUM_VERSION ]]; then
        FZF_MARKS_COMMAND="fzf --height 40% --reverse"
    elif [[ ${FZF_TMUX:-1} -eq 1 ]]; then
        FZF_MARKS_COMMAND="fzf-tmux -d${FZF_TMUX_HEIGHT:-40%}"
    else
        FZF_MARKS_COMMAND="fzf"
    fi
fi

function mark {
    local mark_to_add
    mark_to_add="${*:-$(basename "$(pwd)")} : $(pwd)"

    if grep -qxFe "${mark_to_add}" "${FZF_MARKS_FILE}"; then
        echo "** The following mark already exists **"
    else
        printf '%s\n' "${mark_to_add}" >> "${FZF_MARKS_FILE}"
        echo "** The following mark has been added **"
    fi
    _fzm_color_marks <<< $mark_to_add
}

function _fzm_handle_symlinks {
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
    printf '%s\n' "${fname}"
}

# Ensure precmds are run after cd
function redraw-prompt {
    local precmd
    for precmd in $precmd_functions; do
        $precmd
    done
    zle reset-prompt
}
zle -N redraw-prompt

function _fzm_color_marks {
    if [[ "${FZF_MARKS_NO_COLORS-}" == "1" ]]; then
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

function _fzm_paste_command {
    local directory="$1"
    LBUFFER="${LBUFFER}$directory"
    zle reset-prompt > /dev/null 2>&1
}

function fzm {
    local delete_key=${FZF_MARKS_DELETE:-ctrl-d} paste_key=${FZF_MARKS_PASTE:-ctrl-v}
    local lines=$(_fzm_color_marks < "${FZF_MARKS_FILE}" | eval ${FZF_MARKS_COMMAND} \
        --ansi \
        --expect='"$delete_key,$paste_key"' \
        --multi \
        --bind=ctrl-y:accept,ctrl-t:toggle+down \
        --header='"ctrl-y:jump, ctrl-t:toggle, $delete_key:delete, $paste_key:paste"' \
        --query='"$*"' \
        --select-1 \
        --tac)
    if [[ -z "$lines" ]]; then
        zle && zle redraw-prompt
        return 1
    fi

    local key=$(head -1 <<< "$lines")

    if [[ $key == "$delete_key" ]]; then
        dmark "-->-->-->" "$(sed 1d <<< "$lines")"
    elif [[ $key == "$paste_key" || ! -t 1 ]]; then
        zle && local FZF_MARKS_PASTE_COMMAND=_fzm_paste_command
        pmark "-->-->-->" "$(tail -1 <<< "$lines")"
    else
        jump "-->-->-->" "$(tail -1 <<< "${lines}")"
    fi
}

function jump {
    local jumpline jumpdir bookmarks
    if [[ $1 == "-->-->-->" ]]; then
        jumpline=$2
    else
        jumpline=$(_fzm_color_marks < "${FZF_MARKS_FILE}" | eval ${FZF_MARKS_COMMAND} \
            --ansi \
            --bind=ctrl-y:accept \
            --header='"ctrl-y:jump"' \
            --query='"$*"' \
            --select-1 \
            --tac)
    fi
    if [[ -n ${jumpline} ]]; then
        jumpdir=$(sed 's/.*: \(.*\)$/\1/;'"s#^~#${HOME}#" <<< $jumpline)
        bookmarks=$(_fzm_handle_symlinks)
        cd "${jumpdir}" || return
        if [[ ! "${FZF_MARKS_KEEP_ORDER}" == 1 && -w ${FZF_MARKS_FILE} ]]; then
            perl -n -i -e "print unless /^\\Q${jumpline//\//\\/}\\E\$/" "${bookmarks}"
            printf '%s\n' "${jumpline}" >> "${FZF_MARKS_FILE}"
        fi
    fi
    zle && zle redraw-prompt
}

function pmark {
    local selected
    if [[ $1 == "-->-->-->" ]]; then
        selected=$2
    else
        selected=$(_fzm_color_marks < "${FZF_MARKS_FILE}" | eval ${FZF_MARKS_COMMAND} \
            --ansi \
            --bind=ctrl-y:accept --header='"ctrl-y:paste"' \
            --query='"$*"' --select-1 --tac)
    fi
    if [[ $selected ]]; then
        selected=$(sed 's/.*: \(.*\)$/\1/;'"s#^~#${HOME}#" <<< "$selected")
        local paste_command=${FZF_MARKS_PASTE_COMMAND:-"printf '%s\n'"}
        eval -- "$paste_command \"\$selected\""
    fi
}

function dmark {
    local marks_to_delete line bookmarks
    if [[ $1 == "-->-->-->" ]]; then
        marks_to_delete=$2
    else
        marks_to_delete=$(_fzm_color_marks < "${FZF_MARKS_FILE}" | eval ${FZF_MARKS_COMMAND} \
            -m --ansi \
            --bind=ctrl-y:accept,ctrl-t:toggle+down --header='"ctrl-y:delete, ctrl-t:toggle"' \
            --query='"$*"' --tac)
    fi
    bookmarks=$(_fzm_handle_symlinks)

    if [[ -n ${marks_to_delete} ]]; then
        while IFS='' read -r line; do
            perl -n -i -e "print unless /^\\Q${line//\//\\/}\\E\$/" "${bookmarks}"
        done <<< "$marks_to_delete"

        [[ $(wc -l <<< "${marks_to_delete}") == 1 ]] \
            && echo "** The following mark has been deleted **" \
            || echo "** The following marks have been deleted **"
        _fzm_color_marks <<< $marks_to_delete
    fi
    zle && zle reset-prompt
}

zle -N dmark
zle -N fzm

bindkey -M emacs ${FZF_MARKS_JUMP:-'^g'} fzm
bindkey -M vicmd ${FZF_MARKS_JUMP:-'^g'} fzm
bindkey -M viins ${FZF_MARKS_JUMP:-'^g'} fzm
if [ "${FZF_MARKS_DMARK-}" ]; then
    bindkey ${FZF_MARKS_DMARK} dmark
fi

command -v compdef >/dev/null 2>&1 || return
# Completion: for documentation, see e.g.
# https://mads-hartmann.com/2017/08/06/writing-zsh-completion-scripts.html
# https://github.com/zsh-users/zsh-completions/blob/master/zsh-completions-howto.org#user-content-actions
function _fzm {
    _arguments -C \
        "1: :(($(sed "s/\\(.*\\) : \\(.*\\)/'\1'\\\\:'\2'/" < "$FZF_MARKS_FILE")))" \
}

compdef _fzm fzm
