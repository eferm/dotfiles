# Bootstrap a new macOS machine — see README.md for setup instructions

.PHONY: help all ssh gpg git zsh brew
.DEFAULT_GOAL := help

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@echo "  all        Run all targets"
	@echo "  ssh        Seed ~/.ssh/config and check for SSH key"
	@echo "  gpg        Check for GPG key"
	@echo "  git        Seed ~/.config/git/config and check signing key"
	@echo "  zsh        Seed ~/.zshrc"
	@echo "  brew       Install Homebrew and packages"

all: brew ssh gpg git zsh
	@echo "=== Done ==="
	@echo "Restart your terminal to pick up .zshrc changes."
	@echo "Open nvim to let Lazy install plugins."

# https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
ssh:
	@needs_seed=false; \
	if [ -f "$(HOME)/.ssh/config" ]; then \
		if grep -q 'Include config.default' "$(HOME)/.ssh/config"; then \
			echo "OK: ~/.ssh/config includes config.default"; \
		else \
			bak="$(HOME)/.ssh/config.bak.$$(date +%Y%m%d%H%M%S)"; \
			mv "$(HOME)/.ssh/config" "$$bak"; \
			echo "Backed up ~/.ssh/config to $$bak"; \
			needs_seed=true; \
		fi; \
	else \
		needs_seed=true; \
	fi; \
	if [ "$$needs_seed" = true ]; then \
		echo 'Include config.default' > "$(HOME)/.ssh/config"; \
		echo "OK: created ~/.ssh/config"; \
	fi
	@if [ -f "$(HOME)/.ssh/id_ed25519" ] || [ -f "$(HOME)/.ssh/id_rsa" ]; then \
		echo "OK: SSH key found"; \
	else \
		echo "WARN: No SSH key found. Generate one:"; \
		echo "  ssh-keygen -t ed25519 -C \"your@email.com\""; \
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

# Seed ~/.config/git/config
git:
	@needs_seed=false; \
	if [ -f "$(HOME)/.config/git/config" ]; then \
		if grep -q 'path = config.default' "$(HOME)/.config/git/config"; then \
			echo "OK: ~/.config/git/config includes config.default"; \
		else \
			bak="$(HOME)/.config/git/config.bak.$$(date +%Y%m%d%H%M%S)"; \
			mv "$(HOME)/.config/git/config" "$$bak"; \
			echo "Backed up ~/.config/git/config to $$bak"; \
			needs_seed=true; \
		fi; \
	else \
		needs_seed=true; \
	fi; \
	if [ "$$needs_seed" = true ]; then \
		printf '%s\n' \
			'[include]' \
			'	path = config.default' \
			'; [user]' \
			';	signingkey = YOUR_KEY_HERE ; gpg --list-secret-keys --keyid-format=long' \
			'; [commit]' \
			';	gpgsign = true' \
			'; [tag]' \
			';	gpgSign = true' \
			'; [includeIf "gitdir:~/Code/Org/"]' \
			';	path = /Users/eferm/Code/Org/.gitconfig' \
			> "$(HOME)/.config/git/config"; \
		echo "OK: created ~/.config/git/config"; \
	fi
	@if grep -v '^[;#]' "$(HOME)/.config/git/config" | grep -q 'signingkey'; then \
		echo "OK: git signing key configured"; \
	else \
		echo "WARN: No git signing key set. Run: gpg --list-secret-keys --keyid-format=long"; \
		echo "Then uncomment signingkey in ~/.config/git/config"; \
	fi

# Seed ~/.zshrc
zsh:
	@needs_seed=false; \
	if [ -f "$(HOME)/.zshrc" ]; then \
		if grep -q 'source ~/.zshrc.default' "$(HOME)/.zshrc"; then \
			echo "OK: ~/.zshrc sources .zshrc.default"; \
		else \
			bak="$(HOME)/.zshrc.bak.$$(date +%Y%m%d%H%M%S)"; \
			mv "$(HOME)/.zshrc" "$$bak"; \
			echo "Backed up ~/.zshrc to $$bak"; \
			needs_seed=true; \
		fi; \
	else \
		needs_seed=true; \
	fi; \
	if [ "$$needs_seed" = true ]; then \
		echo 'source ~/.zshrc.default' > "$(HOME)/.zshrc"; \
		echo "OK: created ~/.zshrc"; \
	fi

# https://brew.sh
# https://github.com/Homebrew/homebrew-bundle
brew:
	@if ! command -v brew &>/dev/null; then \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
	else \
		echo "OK: Homebrew already installed"; \
	fi
	brew update
	brew bundle --file=$(HOME)/Brewfile
