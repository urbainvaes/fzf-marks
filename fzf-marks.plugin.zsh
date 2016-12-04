if [[ -z $BOOKMARKS_FILE ]] ; then
    export BOOKMARKS_FILE="$HOME/.bookmarks"
fi

if [[ ! -f $BOOKMARKS_FILE ]]; then
    touch $BOOKMARKS_FILE
fi

function mark() {
    echo $@ : $(pwd) >> $BOOKMARKS_FILE
}

fzfcmd() {
   [ ${FZF_TMUX:-1} -eq 1 ] && echo "fzf-tmux -d${FZF_TMUX_HEIGHT:-40%}" || echo "fzf"
}

function jump() {
    local jumpline
    jumpline=$(cat ${BOOKMARKS_FILE} | $(fzfcmd) --bind=ctrl-y:accept --tac)
    if [[ -n ${jumpline} ]]; then
        local jumpdir
        jumpdir=$(echo "${jumpline}" | sed -n "s/.* : \(.*\)$/\1/p" | sed "s#~#$HOME#")
        perl -p -i -e "s#${jumpline}\n##g" $BOOKMARKS_FILE
        cd "${jumpdir}" && echo ${jumpline} >> $BOOKMARKS_FILE
    fi
    zle && zle reset-prompt
}

function dmark()  {
    local marks_to_delete line
    marks_to_delete=$(cat $BOOKMARKS_FILE | $(fzfcmd) -m --bind=ctrl-y:accept,ctrl-t:toggle-up --tac)

    if [[ -n ${marks_to_delete} ]]; then
        while read -r line; do
            perl -p -i -e "s#${line}\n##g" $BOOKMARKS_FILE
        done <<< "$marks_to_delete"

        echo "** The following marks were deleted **"
        echo "${marks_to_delete}"
    fi
}

zle -N jump
bindkey '^g' jump
