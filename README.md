# fzf-marks
This tiny script, inspired by [zshmarks](https://github.com/jocelynmallon/zshmarks), can be used to create, delete, and navigate marks in Bash and Zsh. It is based on the command-line fuzzy-finder [fzf](https://github.com/junegunn/fzf) written by Junegunn Choi. Although the script is very short and simple, it is very convenient and can very quickly become an important part of your workflow.

![](https://raw.github.com/uvaes/fuzzy-zsh-marks/demo/demo.gif)

## Usage
Most of the key mappings in the search window are the default fzf ones. The most relevant ones are:

- **ctrl-n** / **ctrl-p** to go to the next/previous match.
- **ctrl-y** / **Enter** to accept a match.
- **ctrl-t** to toggle a match for deletion.

In Zsh or Bash, the script creates three commands:

- **mark** to create a new bookmark. For example, `mark work` creates a bookmark labeled work.
- **jump** to jump to a given bookmark using fzf. By default, the script binds this function to **ctrl-n**.
- **dmark** to delete marks toggled for deletion. 

## To do list

- Merge **jump** and **dmark** in one unique function, if allowed by fzf.
- Integrate in zsh prompt.
- Improve robustness.

## Sources

- https://github.com/jocelynmallon/zshmarks
- https://github.com/junegunn/fzf

## Author

Urbain Vaes
