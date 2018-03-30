# fzf-marks
This thin plugin can be used to create, delete, and navigate marks in Bash and Zsh.
It depends on Junegunn Choi's fuzzy-finder [fzf](https://github.com/junegunn/fzf).

![](https://raw.github.com/uvaes/fuzzy-zsh-marks/demo/demo.gif)

## Installation

If you use zsh, I recommend installing with a plugin manager.
With [zgen](https://github.com/tarjoilija/zgen),
this can be done by adding the following line to the plugin list.
```zsh
    zgen load urbainvaes/fzf-marks
```

If you use bash,
or if you use zsh without without a plugin manager,
the plugin can be enabled by sourcing the file
`fzf-marks.plugin.bash` or `fzf-marks.plugin.zsh` from your shell startup file.

**Bash installation example**:
```bash
# Clone the git repository in the current directory
git clone https://github.com/urbainvaes/fzf-marks.git

# Add a line to ~/.bashrc to source the plugin whenever bash start in interactive mode
echo "source $PWD/fzf-marks/fzf-marks.plugin.bash" >> ~/.bashrc

# Source the plugin now so we don't have to restart bash to start using it
source fzf-marks/fzf-marks.plugin.bash
```

## Usage
Most of the key bindings in the search window are the default fzf ones.
The most relevant ones are:

- **ctrl-n** / **ctrl-p** to go to the next/previous match.
- **ctrl-y** or **Enter** to accept a match.
- **ctrl-t** to toggle a match for deletion.

In Zsh or Bash, the script creates three commands:

- **mark** to create a new bookmark. For example, `mark work` creates a bookmark labeled work.
- **jump** to jump to a given bookmark using fzf. By default, the script binds this function to **ctrl-g**.
- **dmark** to delete marks toggled for deletion.

## License

MIT
