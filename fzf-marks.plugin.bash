if [[ -z $BOOKMARKS_FILE ]] ; then
    export BOOKMARKS_FILE="$HOME/.bookmarks"
fi

if [[ ! -f $BOOKMARKS_FILE ]]; then
    touch $BOOKMARKS_FILE
fi

function mark() {
    echo "$@ : $(pwd)" >> $BOOKMARKS_FILE
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
    jumpline=$(cat ${BOOKMARKS_FILE} | $(fzfcmd) --bind=ctrl-y:accept --tac)
    if [[ -n ${jumpline} ]]; then
        jumpdir=$(echo "${jumpline}" | sed -n "s/.* : \(.*\)$/\1/p" | sed "s#~#$HOME#")
        bookmarks=$(handle_symlinks)
        perl -p -i -e "s#${jumpline}\n##g" "${bookmarks}"
        cd "${jumpdir}" && echo ${jumpline} >> $BOOKMARKS_FILE
    fi
}

function dmark()  {
    local marks_to_delete line bookmarks
    marks_to_delete=$(cat $BOOKMARKS_FILE | $(fzfcmd) -m --bind=ctrl-y:accept,ctrl-t:toggle-up --tac)
    bookmarks=$(handle_symlinks)

    if [[ -n ${marks_to_delete} ]]; then
        while read -r line; do
            perl -p -i -e "s#${line}\n##g" ${bookmarks}
        done <<< "$marks_to_delete"

        echo "** The following marks were deleted **"
        echo "${marks_to_delete}"
    fi
}

bind '"\C-g":"jump\n"'
