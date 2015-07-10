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

function fzf-marks-navigate() {
    jumpline=$(cat ${BOOKMARKS_FILE} | $(fzfcmd) --bind=ctrl-y:accept --tac)
    if [[ -n ${jumpline} ]]; then
        jumpdir=$(echo $jumpline | awk '{print $3}')
        sed -i "\#${jumpline}#d" $BOOKMARKS_FILE
        echo ${jumpline} >> $BOOKMARKS_FILE

        LBUFFER="cd ${jumpdir}"
        zle && zle redisplay && zle accept-line
    fi

    zle && zle reset-prompt
}

function dmark()  {
    marks_to_delete=$(cat $BOOKMARKS_FILE | $(fzfcmd) -m --bind=ctrl-y:accept,ctrl-t:toggle-up --tac)

    while read -r line; do
        sed -i "\#${line}#d" $BOOKMARKS_FILE
    done <<< "$marks_to_delete"

    echo "** The following marks were deleted **"
    echo ${marks_to_delete}
}

zle -N fzf-marks-navigate
