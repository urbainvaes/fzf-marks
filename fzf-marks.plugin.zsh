if [[ -z "${BOOKMARKS_FILE}" ]] ; then
    export BOOKMARKS_FILE="${HOME}/.bookmarks"
fi

if [[ ! -f "${BOOKMARKS_FILE}" ]]; then
    touch "${BOOKMARKS_FILE}"
fi

function mark() {
    local mark_to_add
    mark_to_add=$(echo "$* : $(pwd)")
    echo ${mark_to_add} >> "${BOOKMARKS_FILE}"

    echo "** The following mark has been added **"
    echo "${mark_to_add}"
}

fzfcmd() {
   [ ${FZF_TMUX:-1} -eq 1 ] && echo "fzf-tmux -d${FZF_TMUX_HEIGHT:-40%}" || echo "fzf"
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

function jump() {
    local jumpline jumpdir bookmarks
    jumpline=$($(fzfcmd) --bind=ctrl-y:accept --tac < "${BOOKMARKS_FILE}")
    if [[ -n ${jumpline} ]]; then
        jumpdir=$(echo "${jumpline}" | sed -n "s/.* : \(.*\)$/\1/p" | sed "s#~#${HOME}#")
        bookmarks=$(handle_symlinks)
        perl -p -i -e "s#${jumpline}\n##g" "${bookmarks}"
        cd "${jumpdir}" && echo "${jumpline}" >> "${BOOKMARKS_FILE}"
    fi
    zle && zle reset-prompt
}

function dmark()  {
    local marks_to_delete line bookmarks
    marks_to_delete=$($(fzfcmd) -m --bind=ctrl-y:accept,ctrl-t:toggle-up --tac < "${BOOKMARKS_FILE}")
    bookmarks=$(handle_symlinks)

    if [[ -n ${marks_to_delete} ]]; then
        while read -r line; do
            perl -p -i -e "s#${line}\n##g" ${bookmarks}
        done <<< "$marks_to_delete"

        echo "** The following marks were deleted **"
        echo "${marks_to_delete}"
    fi
}

zle -N jump
bindkey '^g' jump
