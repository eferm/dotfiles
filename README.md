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

# 4. Create a machine-specific branch
dotfiles checkout -b local

# 5. Configure machine-specific settings (e.g. git signing key)
nvim ~/.config/git/config
dotfiles commit -am "configure <machine-name>"

# 6. Optionally remove bootstrap files from ~
rm ~/Brewfile ~/Makefile ~/README.md
dotfiles commit -am "clean up home"
```

## Pulling shared updates

When `main` is updated, merge into your machine branch:

```bash
dotfiles fetch origin
dotfiles merge FETCH_HEAD
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
