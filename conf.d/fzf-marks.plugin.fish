# MIT License

# Copyright (c) 2019 Marcel Patzwahl, Urbain Vaes

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

command -v fzf > /dev/null 2>&1 or return

if test -z "$FZF_MARKS_FILE"
    set -g FZF_MARKS_FILE "$HOME/.fzf-marks"
end

if test ! -f "$FZF_MARKS_FILE"
    touch "$FZF_MARKS_FILE"
end

if test -z "$FZF_MARKS_COMMAND"
    set -l fzf_version (fzf --version | awk -F. '{ print $1 * 1e6 + $2 * 1e3 + $3 }')
    set -l minimum_version 16001

    if test $fzf_version -gt $minimum_version
        set -g FZF_MARKS_COMMAND fzf --height 40% --reverse --header=\'ctrl-y:jump, ctrl-t:toggle, ctrl-d:delete\'
    else if test $FZF_TMUX -eq 1
        set -l tmux_height $FZF_TMUX_HEIGHT
        set -lq tmux_height[1]; or set tmux_height[1] 40
        set -g FZF_MARKS_COMMAND "fzf-tmux -d$tmux_height"
    else
        set -g FZF_MARKS_COMMAND "fzf"
    end
end

function mark
    set -l mark_to_add "$argv : "(pwd)

    if grep -qxFe "$mark_to_add" "$FZF_MARKS_FILE"
        echo "** The following mark already exists **"
    else
        echo "$mark_to_add" >> "$FZF_MARKS_FILE"
        echo "** The following mark has been added **"
    end
    echo "$mark_to_add" | _color_marks
end

function _handle_symlinks
    if test -L $FZF_MARKS_FILE
        set -l link (readlink "$FZF_MARKS_FILE")
        switch $link
            case '/*'
                echo $link
            case '*'
                echo (dirname $FZF_MARKS_FILE)/$link
        end
    else
        echo $FZF_MARKS_FILE
    end
end

function _color_marks
    if test "$FZF_MARKS_NO_COLORS" = "1"
        cat
    else
        set -l esc (printf '\033')
        set -l c_lhs $FZF_MARKS_COLOR_LHS
        set -lq c_lhs[1]; or set c_lhs[1] 39
        set -l c_rhs $FZF_MARKS_COLOR_RHS
        set -lq c_rhs[1]; or set c_rhs[1] 36
        set -l c_colon $FZF_MARKS_COLOR_COLON
        set -lq c_colon[1]; or set c_colon[1] 33
        sed "s/^\\(.*\\) : \\(.*\\)\$/"$esc"["$c_lhs"m\\1"$esc"[0m "$esc"["$c_colon"m:"$esc"[0m "$esc"["$c_rhs"m\\2"$esc"[0m/"
    end
end

function fzm
    set -l marks_del $FZF_MARKS_DELETE
    set -lq marks_del[1]; or set marks_del[1] "ctrl-d"

    set lines (_color_marks < $FZF_MARKS_FILE | eval $FZF_MARKS_COMMAND \
               --ansi \
               --expect="$marks_del" \
               --multi \
               --bind=ctrl-y:accept,ctrl-t:toggle+down \
               --query=$argv \
               --select-1 \
               --tac)
    if test -z "$lines"
        commandline -f repaint
        return 1
    end
    set -l key (echo "$lines" | head -1 | string split " ")
    if test $marks_del = $key[1]
        dmark "-->-->-->" (echo "$key[2..-1]")
    else
        jump "-->-->-->" (echo "$lines" | tail -1)
    end
end

function jump
    if test $argv[1] = "-->-->-->"
        set jumpline $argv[2]
    else
        set jumpline (_color_marks < $FZF_MARKS_FILE | $FZF_MARKS_COMMAND \
                --ansi \
                --bind=ctrl-y:accept \
                --query="$argv" \
                --select-1 \
                --tac)
    end
    if test -n $jumpline
        set -l jumpdir (echo "$jumpline" | sed 's/.*: \(.*\)$/\1/' | sed "s#^~#$HOME#")
        set -l bookmarks (_handle_symlinks)
        cd $jumpdir
        commandline -f repaint
    end
end

function dmark
    if test $argv[1] = "-->-->-->"
        set marks_to_delete $argv[2]
    else
        set marks_to_delete (_color_marks < $FZF_MARKS_FILE | $FZF_MARKS_COMMAND \
                -m \
                --ansi \
                --bind=ctrl-y:accept,ctrl-t:toggle+down \
                --query="$argv" \
                --tac)
    end
    set -l bookmarks (_handle_symlinks)
    for line in $marks_to_delete
        set -l line (string replace -a "/" "\/" $line)
        perl -n -i -e "print unless /^\Q$line\E\$/" "$bookmarks"
    end
    if test (echo $marks_to_delete | wc -l) = 1
        echo "** The following mark has been deleted **"
        echo "$marks_to_delete" | _color_marks
    else
        echo "** The following marks have been deleted **"
        echo "$marks_to_delete" | _color_marks
    end
    commandline -f repaint
end

set -q FZF_MARKS_JUMP; or set FZF_MARKS_JUMP \cg
bind -M insert $FZF_MARKS_JUMP fzm
bind $FZF_MARKS_JUMP fzm

if test -n "$FZF_MARKS_DMARK"
    bind -M insert "$FZF_MARKS_DMARK" dmark
    bind "$FZF_MARKS_DMARK" dmark
end
