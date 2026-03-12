# dotfiles

Bare git repo for managing dotfiles across machines.

Shared config lives in version-controlled `.default` files. Machine-specific
config lives in untracked files that include/source the defaults.

## New machine setup

```bash
# 1. Clone the bare repo
git clone --bare git@github.com:eferm/dotfiles.git $HOME/.dotfiles

# 2. Check out dotfiles into $HOME
alias dotfiles='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
dotfiles checkout   # if this fails, back up conflicting files first
dotfiles config status.showUntrackedFiles no

# 3. Bootstrap
make all 
```

Then restart Ghostty to pick up the configured environment.

## Usage

```bash
dotfiles ls-files            # list all tracked files
dotfiles status              # check status
dotfiles add ~/.some/file    # track a file
dotfiles commit -m "msg"     # commit changes
dotfiles push/pull           # push/pull to remote
make                         # list available targets
make all                     # run full bootstrap
```

## Obsidian

Version-controls Obsidian vaults using a bare git repo. This is optional but
acts as a safeguard when letting LLMs rip inside of a vault.

### Folder structure

```
~/Documents/
├── .obsgit/             # bare git repo
└── Obsidian/            # vaults go in here; git work tree
    ├── .gitignore
    ├── .gitattributes   # LFS tracking rules
    └── My Vault/        # an Obsidian vault folder
        ├── .obsidian/   # ignored - Obsidian config
        ├── .trash/      # ignored - Obsidian trash
        └── Attachments/ # tracked via LFS
```

### Setup

```bash
# Create bare repo
git init --bare ~/Documents/.obsgit

# Add aliases
alias obsgit='git --git-dir=$HOME/Documents/.obsgit --work-tree=$HOME/Documents/Obsidian'
alias obslazy='lazygit --git-dir=$HOME/Documents/.obsgit --work-tree=$HOME/Documents/Obsidian'

# Enter work tree
cd ~/Documents/Obsidian/

# Set up LFS for attachments; assumes `brew install git-lfs`
obsgit lfs install
obsgit lfs track "My Vault/Attachments/**"

# Add files
echo '.obsidian/
.trash/' > .gitignore
obsgit add .gitignore
obsgit add .gitattributes
obsgit add "My Vault/"
obsgit commit -m "initial import"
```

```bash
# Snapshot vault state
obsgit status
obsgit add -u
obsgit commit -m "save state"

# or just use lazygit
obslazy
```
