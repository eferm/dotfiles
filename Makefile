# Bootstrap a new macOS machine — see README.md for setup instructions

TIMESTAMP := $(shell date +%Y%m%d%H%M%S)

.PHONY: default
default: help

.PHONY: help
help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@echo "  all        Run install, seed, check"
	@echo "  install    Install Homebrew and packages"
	@echo "  seed       Seed config files from defaults"
	@echo "  check      Verify SSH key, GPG key, Git signing key"
	@echo "  clean      Back up config files and re-seed"

.PHONY: all
all: install seed check
	@echo ""
	@echo "=== Done ==="
	@echo "Restart your terminal to pick up .zshrc changes."
	@echo "Open nvim to let Lazy install plugins."

# https://brew.sh
# https://github.com/Homebrew/homebrew-bundle
# https://code.claude.com/docs/en/overview
.PHONY: install
install:
	@if ! command -v brew &>/dev/null; then \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
	else \
		echo "OK: Homebrew already installed"; \
	fi
	brew update
	brew bundle --file=$(HOME)/Brewfile
	@if command -v claude &>/dev/null; then \
		echo "OK: Claude Code already installed"; \
	else \
		curl -fsSL https://claude.ai/install.sh | bash; \
	fi

.PHONY: seed
seed: seed-ssh seed-git seed-zsh

.PHONY: seed-ssh
seed-ssh:
	@if [ -f "$(HOME)/.ssh/config" ] && grep -q 'Include config.default' "$(HOME)/.ssh/config"; then \
		echo "OK: ~/.ssh/config includes config.default"; \
	else \
		if [ -f "$(HOME)/.ssh/config" ]; then \
			bak="$(HOME)/.ssh/config.bak.$(TIMESTAMP)"; \
			mv "$(HOME)/.ssh/config" "$$bak"; \
			echo "Backed up ~/.ssh/config to $$bak"; \
		fi; \
		echo 'Include config.default' > "$(HOME)/.ssh/config"; \
		echo "OK: created ~/.ssh/config"; \
	fi

.PHONY: seed-git
seed-git:
	@if [ -f "$(HOME)/.config/git/config" ] && grep -q 'path = config.default' "$(HOME)/.config/git/config"; then \
		echo "OK: ~/.config/git/config includes config.default"; \
	else \
		if [ -f "$(HOME)/.config/git/config" ]; then \
			bak="$(HOME)/.config/git/config.bak.$(TIMESTAMP)"; \
			mv "$(HOME)/.config/git/config" "$$bak"; \
			echo "Backed up ~/.config/git/config to $$bak"; \
		fi; \
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
			';	path = ~/Code/Org/.gitconfig' \
			> "$(HOME)/.config/git/config"; \
		echo "OK: created ~/.config/git/config"; \
	fi

.PHONY: seed-zsh
seed-zsh:
	@if [ -f "$(HOME)/.zshrc" ] && grep -q 'source ~/.zshrc.default' "$(HOME)/.zshrc"; then \
		echo "OK: ~/.zshrc sources .zshrc.default"; \
	else \
		if [ -f "$(HOME)/.zshrc" ]; then \
			bak="$(HOME)/.zshrc.bak.$(TIMESTAMP)"; \
			mv "$(HOME)/.zshrc" "$$bak"; \
			echo "Backed up ~/.zshrc to $$bak"; \
		fi; \
		echo 'source ~/.zshrc.default' > "$(HOME)/.zshrc"; \
		echo "OK: created ~/.zshrc"; \
	fi

.PHONY: check
check: check-ssh check-gpg check-git

# https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
.PHONY: check-ssh
check-ssh:
	@if [ -f "$(HOME)/.ssh/id_ed25519" ] || [ -f "$(HOME)/.ssh/id_rsa" ]; then \
		echo "OK: SSH key found"; \
	else \
		echo "WARN: No SSH key found. Generate one:"; \
		echo "  ssh-keygen -t ed25519 -C \"your@email.com\""; \
	fi

# https://docs.github.com/en/authentication/managing-commit-signature-verification/generating-a-new-gpg-key
.PHONY: check-gpg
check-gpg:
	@if gpg --list-secret-keys --keyid-format=long 2>/dev/null | grep -q sec; then \
		echo "OK: GPG key found"; \
	else \
		echo "WARN: No GPG key found."; \
		echo ""; \
		echo "  To import an existing key:"; \
		echo "    gpg --import your@id.here.priv.asc"; \
		echo "    gpg --edit-key your@id.here"; \
		echo "    gpg> trust"; \
		echo "    Your decision? 5 (Ultimate trust)"; \
		echo ""; \
		echo "  To generate a new key:"; \
		echo "    gpg --full-generate-key"; \
	fi

.PHONY: check-git
check-git:
	@if grep -v '^[;#]' "$(HOME)/.config/git/config" | grep -q 'signingkey'; then \
		echo "OK: git signing key configured"; \
	else \
		echo "WARN: No git signing key set. Run: gpg --list-secret-keys --keyid-format=long"; \
		echo "Then add signingkey to ~/.config/git/config"; \
	fi

.PHONY: clean
clean:
	@echo "Backing up configs..."
	@for f in "$(HOME)/.ssh/config" "$(HOME)/.config/git/config" "$(HOME)/.zshrc"; do \
		if [ -f "$$f" ]; then \
			bak="$$f.bak.$(TIMESTAMP)"; \
			mv "$$f" "$$bak"; \
			echo "  $$f -> $$bak"; \
		fi; \
	done
	@$(MAKE) seed
