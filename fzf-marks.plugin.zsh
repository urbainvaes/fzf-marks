if [[ -z "${BOOKMARKS_FILE}" ]] ; then
    export BOOKMARKS_FILE="${HOME}/.bookmarks"
fi

if [[ ! -f "${BOOKMARKS_FILE}" ]]; then
    touch "${BOOKMARKS_FILE}"
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

function mark() {
    local mark_to_add
    mark_to_add=$(echo "$* : $(pwd)")
    echo "${mark_to_add}" >> "${BOOKMARKS_FILE}"

    echo "** The following mark has been added **"
    echo "${mark_to_add}"
}

function handle_symlinks() {
    local fname
    if [ -L "${BOOKMARKS_FILE}" ]; then
        fname=$(readlink "${BOOKMARKS_FILE}")
    else
        fname=${BOOKMARKS_FILE}
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

function jump() {
    local jumpline jumpdir bookmarks
    jumpline=$($(echo ${FZF_MARKS_COMMAND}) --bind=ctrl-y:accept --query="$*" --select-1 --tac < "${BOOKMARKS_FILE}")
    if [[ -n ${jumpline} ]]; then
        jumpdir=$(echo "${jumpline}" | sed -n "s/.* : \(.*\)$/\1/p" | sed "s#~#${HOME}#")
        bookmarks=$(handle_symlinks)
        perl -p -i -e "s#${jumpline}\n##g" "${bookmarks}"
        cd "${jumpdir}" && echo "${jumpline}" >> "${BOOKMARKS_FILE}"
    fi
    zle && zle redraw-prompt
}

function dmark()  {
    local marks_to_delete line bookmarks
    marks_to_delete=$($(echo ${FZF_MARKS_COMMAND}) -m --bind=ctrl-y:accept,ctrl-t:toggle --query="$*" --tac < "${BOOKMARKS_FILE}")
    bookmarks=$(handle_symlinks)

    if [[ -n ${marks_to_delete} ]]; then
        while read -r line; do
            perl -p -i -e "s#${line}\n##g" ${bookmarks}
        done <<< "$marks_to_delete"

        echo "** The following marks have been deleted **"
        echo "${marks_to_delete}"
    fi
}

zle -N jump
bindkey '^g' jump
