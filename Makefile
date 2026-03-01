# Bootstrap a new macOS machine — see README.md for setup instructions

.PHONY: help all ssh gpg git brew packages
.DEFAULT_GOAL := help

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@echo "  all       Run all targets"
	@echo "  ssh       Check for SSH key"
	@echo "  gpg       Check for GPG key"
	@echo "  git       Check for git config.local"
	@echo "  brew      Install Homebrew"
	@echo "  packages  Install/update Homebrew packages"

all: ssh gpg git brew packages
	@echo "=== Done ==="
	@echo "Restart your terminal to pick up .zshrc changes."
	@echo "Open nvim to let Lazy install plugins."

# https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
ssh:
	@if [ -f "$(HOME)/.ssh/id_ed25519" ] || [ -f "$(HOME)/.ssh/id_rsa" ]; then \
		echo "OK: SSH key found"; \
	else \
		echo "FAIL: No SSH key found. Generate a new key."; \
		echo "  ssh-keygen -t ed25519 -C \"your@email.com\""; \
		exit 1; \
	fi

# https://docs.github.com/en/authentication/managing-commit-signature-verification/generating-a-new-gpg-key
gpg:
	@if gpg --list-secret-keys --keyid-format=long 2>/dev/null | grep -q sec; then \
		echo "OK: GPG key found"; \
	else \
		echo "FAIL: No GPG key found."; \
		echo ""; \
		echo "  To import an existing key:"; \
		echo "    gpg --import your@id.here.priv.asc"; \
		echo "    gpg --edit-key your@id.here"; \
		echo "    gpg> trust"; \
		echo "    Your decision? 5 (Ultimate trust)"; \
		echo ""; \
		echo "  To generate a new key:"; \
		echo "    gpg --full-generate-key"; \
		echo ""; \
		exit 1; \
	fi

git:
	@if [ -f "$(HOME)/.config/git/config.local" ]; then \
		echo "OK: git config.local found"; \
	else \
		echo "FAIL: ~/.config/git/config.local not found. Create it with:"; \
		echo ""; \
		echo "  [user]"; \
		echo "  	signingkey = <YOUR_GPG_KEY_ID>"; \
		echo "  [commit]"; \
		echo "  	gpgsign = true"; \
		echo "  [tag]"; \
		echo "  	gpgSign = true"; \
		echo "  [includeIf \"gitdir:~/Code/org-name/\"]"; \
		echo "  	path = ~/Code/org-name/.gitconfig"; \
		echo ""; \
		exit 1; \
	fi

# https://brew.sh/
brew:
	@echo "=== Installing Homebrew ==="
	@if ! command -v brew &>/dev/null; then \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
	else \
		echo "Homebrew already installed"; \
	fi

# https://github.com/Homebrew/homebrew-bundle
packages: brew
	@echo "=== Installing/updating packages ==="
	brew update
	brew bundle --file=$(HOME)/Brewfile
