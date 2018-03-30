# fzf-marks
This plugin can be used to create, delete, and navigate marks in *bash* and *zsh*.
It depends on Junegunn Choi's fuzzy-finder [fzf](https://github.com/junegunn/fzf).

![](https://raw.github.com/uvaes/fuzzy-zsh-marks/demo/demo.gif)

# Installation

If you use *zsh*, I recommend installing with a plugin manager.
In the case of [zgen](https://github.com/tarjoilija/zgen), for example,
simply add the following line to your plugin list:
```zsh
    zgen load urbainvaes/fzf-marks
```

If you use *bash*,
or if you use *zsh* without a plugin manager,
source the file `fzf-marks.plugin.bash` or `fzf-marks.plugin.zsh` from your shell startup file
to enable the plugin.

**Bash installation example**:
```bash
# Clone the git repository in the current directory
git clone https://github.com/urbainvaes/fzf-marks.git

# Add a line to ~/.bashrc to load the plugin whenever bash starts in interactive mode
echo "source $PWD/fzf-marks/fzf-marks.plugin.bash" >> ~/.bashrc

# Source the plugin now so we don't have to restart bash to start using it
source fzf-marks/fzf-marks.plugin.bash
```

# Usage
Most of the keybindings in the search window are the default fzf ones.
The only additions are

- **ctrl-y**, to accept a match;
- **ctrl-t**, to toggle a match for deletion.

The script creates three commands:

- **mark**, to create a new mark;
- **jump**, to jump to a mark;
- **dmark**, to delete the marks toggled for deletion.

# Customization

| Config              | Default                      | Description                    |
| ------              | -------                      | -----------                    |
| `FZF_MARKS_FILE`    | `${HOME}/.fzf-marks`         | File containing the marks data |
| `FZF_MARKS_COMMAND` | `fzf --height 40% --reverse` | Command used to call `fzf`     |
| `FZF_MARKS_JUMP`    | `\C-g` (*bash*) or `^g` (*zsh*)  | Keybinding to `jump`           |
| `FZF_MARKS_DMARK`   | None                         | Keybinding to `dmark`          |

# License

MIT
