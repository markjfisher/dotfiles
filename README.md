# dotfiles

For use with `stow` to symlink config files into home dir.

## usage

```shell
cd ~/dotfiles
stow --adopt --no-folding hyprland
```

The args ensure the folder structure is created, not linked (no-folding), and
the files if they already exist are used from the dotfiles repo and replaced
with symlinks.
