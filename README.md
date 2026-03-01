# dotfiles

Bare git repo for managing dotfiles across machines.

## New machine setup

```bash
# 1. Clone the bare repo
git clone --bare git@github.com:eferm/dotfiles.git $HOME/.dotfiles

# 2. Set up the alias and checkout
alias dotfiles='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
dotfiles checkout   # if this fails, back up conflicting files first
dotfiles config status.showUntrackedFiles no

# 3. Run bootstrap
source ~/.zshrc
make all
```

After setup, you can delete the non-dotfiles from `~` — they're only needed for bootstrapping:

```bash
rm ~/Brewfile ~/Makefile ~/README.md
```

## Usage

```bash
dotfiles ls-files            # list all tracked files
dotfiles status              # check status
dotfiles add ~/.some/file    # track a file
dotfiles commit -m "msg"     # commit changes
dotfiles push/pull           # push/pull to remote
make                         # list available targets
make all                     # run bootstrap checks and install packages
```
