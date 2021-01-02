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
        FZF_MARKS_COMMAND="fzf --height 40% --reverse --header='ctrl-y:jump, ctrl-t:toggle, ctrl-d:delete, ctrl-k:paste'"
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
        --expect='"${FZF_MARKS_DELETE:-ctrl-d},${FZM_MARKS_PASTE:-ctrl-k}"' \
        --multi \
        --bind=ctrl-y:accept,ctrl-t:toggle \
        --query='"$*"' \
        --select-1 \
        --tac)
    if [[ -z "$lines" ]]; then
        return 1
    fi

    key=$(head -1 <<< "$lines")

    if [[ $key == "${FZF_MARKS_DELETE:-ctrl-d}" ]]; then
        dmark "-->-->-->" "$(sed 1d <<< "$lines")"
    elif [[ $key == "${FZF_MARKS_PASTE:-ctrl-k}" ]]; then
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
        jumpline=$(_color_marks < "${FZF_MARKS_FILE}" | eval ${FZF_MARKS_COMMAND} --ansi --bind=ctrl-y:accept --query='"$*"' --select-1 --tac)
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

function pmark {
    local selected
    if [[ $1 == "-->-->-->" ]]; then
        selected=$2
    else
        local _fzm_keymap_description="ctrl-y:paste"
        selected=$(_color_marks < "${FZF_MARKS_FILE}" | eval ${FZF_MARKS_COMMAND} --ansi --bind=ctrl-y:accept --query='"$*"' --select-1 --tac)
    fi
    if [[ $selected ]]; then
        selected=$(sed 's/.*: \(.*\)$/\1/;s#^~#${HOME}#' <<< $selected)
        local paste_command=${FZF_MARKS_PASTE_COMMAND:-"printf '%s\n'"}
        eval -- "$paste_command \"\$selected\""
    fi
}

function dmark {
    local marks_to_delete line bookmarks
    if [[ $1 == "-->-->-->" ]]; then
        marks_to_delete=$2
    else
        marks_to_delete=$(_color_marks < "${FZF_MARKS_FILE}" | eval ${FZF_MARKS_COMMAND} -m --ansi --bind=ctrl-y:accept,ctrl-t:toggle --query='"$*"' --tac)
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

if ((BASH_VERSINFO[0] >= 4)); then
    # Widget for Bash 4.0+

    # bashbug https://lists.gnu.org/archive/html/bug-bash/2018-04/msg00040.html
    function _fzm-widget-has_readline_point_bug {
      [[ BASH_VERSINFO[0] -lt 5 && ! $_ble_attached ]]
    }
    function _fzm-widget-has_readline_mark {
      [[ BASH_VERSINFO[0] -ge 5 || $_ble_attached ]]
    }
    function _fzm-widget-insert {
        local insert=$1

        # Work around bashbug
        if _fzm-widget-has_readline_point_bug; then
            # Convert READLINE_POINT from bytes to characters
            local old_lc_all=$LC_ALL old_lc_ctype=$LC_CTYPE
            local LC_ALL= LC_CTYPE=C
            local head=${READLINE_LINE::READLINE_POINT}
            LC_ALL=$old_lc_all LC_CTYPE=$old_lc_ctype
            READLINE_POINT=${#head}
        fi

        READLINE_LINE=${READLINE_LINE::READLINE_POINT}$insert${READLINE_LINE:READLINE_POINT}
        if _fzm-widget-has_readline_mark && ((READLINE_MARK > READLINE_POINT)); then
            # Bash 5.0 has new variable READLINE_MARK
            ((READLINE_MARK += ${#insert}))
        fi
        ((READLINE_POINT += ${#insert}))

        # Work around bashbug
        if _fzm-widget-has_readline_point_bug; then
            # Convert READLINE_POINT from characters to bytes
            local head=${READLINE_LINE::READLINE_POINT}
            local LC_ALL= LC_CTYPE=C
            READLINE_POINT=${#head}
            LC_ALL=$old_lc_all LC_CTYPE=$old_lc_ctype
        fi
    } 2>/dev/null # Suppress locale error messages
    function _fzm-widget-stash_line {
        _fzm_line=$READLINE_LINE
        _fzm_point=$READLINE_POINT
        READLINE_LINE=
        READLINE_POINT=0
        if _fzm-widget-has_readline_mark; then
            _fzm_mark=$READLINE_MARK
            READLINE_MARK=0
        fi
    }
    function _fzm-widget-pop_line {
        READLINE_LINE=$_fzm_line
        READLINE_POINT=$_fzm_point
        if _fzm-widget-has_readline_mark; then
             READLINE_MARK=$_fzm_mark
        fi
    }
    function _fzm-widget {
        local pwd=$PWD
        local FZF_MARKS_PASTE_COMMAND=_fzm-widget-insert
        fzm

        if [[ $PWD != "$pwd" ]]; then
            # Force the prompt update
            _fzm-widget-stash_line
            bind "\"$_fzm_key2\": \"\C-m$_fzm_key3\""
            bind -x "\"$_fzm_key3\": _fzm-widget-pop_line"
        else
            bind "\"$_fzm_key2\": \"\""
        fi
    }

else
    # Widget for Bash 3.0-3.2
    function _fzm-widget-untranslate_keyseq {
        local value=$1
        if [[ $value == *[\'\"$'\001'-$'\037']* ]]; then
            local a b
            a='\' b='\\' value=${value//$a/$b}
            a='"' b='\"' value=${value//$a/$b}
            a=$'\001' b='\C-q\001' value=${value//$a/$b}
            a=$'\002' b='\C-q\002' value=${value//$a/$b}
            a=$'\003' b='\C-q\003' value=${value//$a/$b}
            a=$'\004' b='\C-q\004' value=${value//$a/$b}
            a=$'\005' b='\C-q\005' value=${value//$a/$b}
            a=$'\006' b='\C-q\006' value=${value//$a/$b}
            a=$'\007' b='\C-q\007' value=${value//$a/$b}
            a=$'\010' b='\C-q\010' value=${value//$a/$b}
            a=$'\011' b='\C-q\011' value=${value//$a/$b}
            a=$'\012' b='\C-q\012' value=${value//$a/$b}
            a=$'\013' b='\C-q\013' value=${value//$a/$b}
            a=$'\014' b='\C-q\014' value=${value//$a/$b}
            a=$'\015' b='\C-q\015' value=${value//$a/$b}
            a=$'\016' b='\C-q\016' value=${value//$a/$b}
            a=$'\017' b='\C-q\017' value=${value//$a/$b}
            a=$'\020' b='\C-q\020' value=${value//$a/$b}
            a=$'\021' b='\C-q\021' value=${value//$a/$b}
            a=$'\022' b='\C-q\022' value=${value//$a/$b}
            a=$'\023' b='\C-q\023' value=${value//$a/$b}
            a=$'\024' b='\C-q\024' value=${value//$a/$b}
            a=$'\025' b='\C-q\025' value=${value//$a/$b}
            a=$'\026' b='\C-q\026' value=${value//$a/$b}
            a=$'\027' b='\C-q\027' value=${value//$a/$b}
            a=$'\030' b='\C-q\030' value=${value//$a/$b}
            a=$'\031' b='\C-q\031' value=${value//$a/$b}
            a=$'\032' b='\C-q\032' value=${value//$a/$b}
            a=$'\033' b='\C-q\033' value=${value//$a/$b}
            a=$'\034' b='\C-q\034' value=${value//$a/$b}
            a=$'\035' b='\C-q\035' value=${value//$a/$b}
            a=$'\036' b='\C-q\036' value=${value//$a/$b}
            a=$'\037' b='\C-q\037' value=${value//$a/$b}
        fi
        _fzm_keyseq=$value
    }
    function _fzm-widget {
        local pwd=$PWD
        local FZF_MARKS_PASTE_COMMAND=_fzm-widget-untranslate_keyseq _fzm_keyseq=
        fzm

        if [[ $PWD != "$pwd" ]]; then
            # Force the prompt update
            _fzm_keyseq=' \C-b\C-k \C-u\C-m\C-y\C-?\e \C-y\ey\C-x\C-x\C-d'$_fzm_keyseq
        fi
        bind "\"$_fzm_key2\": \"$_fzm_keyseq\""
    }
fi

# Widget for ble.sh
function ble/widget/fzm {
    ble/widget/.hide-current-line
    ble/util/buffer.flush >&2

    local pwd=$PWD
    local FZF_MARKS_PASTE_COMMAND=ble/widget/insert-string
    fzm

    # Force the prompt update
    [[ $PWD != "$pwd" ]] && ble/prompt/clear
}

function set-up-fzm-bindings {
    local jump_key=${FZF_MARKS_JUMP:-'\C-g'}
    if ((_ble_version>=400)); then
        ble-bind -f keyseq:"$jump_key" 'fzm'
    else
        # Intiialize special keys used for key bindings
        _fzm_key1='\200'
        _fzm_key2='\201'
        _fzm_key3='\202'
        local locale=${LC_ALL:-${LC_CTYPE:-$LANG}}
        local rex_utf8='\.([uU][tT][fF]-?8)$'
        if [[ $locale =~ $rex_utf8 ]]; then
            # Change keys for UTF-8 encodings:
            # Two-byte sequence does not work for Bash 3 and 4.
            # \xC0-\xC1 and \xF5-\xFF are unused bytes in UTF-8.
            # Bash 4 unintendedly exits with \xFE-\xFF.
            _fzm_key1='\xC0'
            _fzm_key2='\xC1'
            _fzm_key3='\xFD'
        fi

        bind -x "\"$_fzm_key1\": _fzm-widget"
        bind "\"$jump_key\":\"$_fzm_key1$_fzm_key2\""
    fi

    if [ "${FZF_MARKS_DMARK}" ]; then
        bind -x "\"${FZF_MARKS_DMARK}\": dmark"
    fi
}

set-up-fzm-bindings
setup_completion
