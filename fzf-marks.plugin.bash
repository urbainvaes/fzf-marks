if [[ -z $BOOKMARKS_FILE ]] ; then
    export BOOKMARKS_FILE="$HOME/.bookmarks"
fi

if [[ ! -f $BOOKMARKS_FILE ]]; then
    touch $BOOKMARKS_FILE
fi

function mark() {
    echo $1 : $(pwd) >> $BOOKMARKS_FILE
}

fzfcmd() {
   [ ${FZF_TMUX:-1} -eq 1 ] && echo "fzf-tmux -d${FZF_TMUX_HEIGHT:-40%}" || echo "fzf"
}

function jump() {
    local jumpline=$(cat ${BOOKMARKS_FILE} | $(fzfcmd) --bind=ctrl-y:accept --tac)
    if [[ -n ${jumpline} ]]; then
        local jumpdir=$(echo $jumpline | awk '{print $3}' | sed "s#~#$HOME#")
        sed --follow-symlinks -i "\#${jumpline}#d" $BOOKMARKS_FILE
        cd ${jumpdir} && echo ${jumpline} >> $BOOKMARKS_FILE
    fi
}

function dmark()  {
    local marks_to_delete=$(cat $BOOKMARKS_FILE | $(fzfcmd) -m --bind=ctrl-y:accept,ctrl-t:toggle-up --tac)

    while read -r line; do
        sed -i --follow-symlinks "\#${line}#d" $BOOKMARKS_FILE
    done <<< "$marks_to_delete"

    echo "** The following marks were deleted **"
    echo ${marks_to_delete}
}

bind '"\C-g":"jump\n"'
