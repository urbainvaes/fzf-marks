if [[ -z $BOOKMARKS_FILE ]] ; then
    export BOOKMARKS_FILE="$HOME/.bookmarks"
fi

if [[ ! -f $BOOKMARKS_FILE ]]; then
    touch $BOOKMARKS_FILE
fi

function mark() {
    echo $1 : $(pwd) >> $BOOKMARKS_FILE
    sort $BOOKMARKS_FILE -o $BOOKMARKS_FILE
    echo "Mark successfully added"
}

fzfcmd() {
   [ ${FZF_TMUX:-1} -eq 1 ] && echo "fzf-tmux -d${FZF_TMUX_HEIGHT:-40%}" || echo "fzf"
}

function jump() {
   cd "${$(cat ${BOOKMARKS_FILE} | $(fzfcmd) --bind=ctrl-y:accept | awk '{print $3}'):-.}"
   zle reset-prompt
}

zle     -N    jump
bindkey '^n'  jump

function dmark()  {
    marks_to_delete=$(cat $BOOKMARKS_FILE | $(fzfcmd) -m --bind=ctrl-y:accept)

    newmarks=$(comm -23 ${BOOKMARKS_FILE} <(echo ${marks_to_delete} | sort))
    echo ${newmarks} > ${BOOKMARKS_FILE}

    echo "** The following marks were deleted **"
    echo ${marks_to_delete}
}
