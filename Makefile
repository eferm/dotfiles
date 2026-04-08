# Bootstrap a new macOS machine — see README.md for setup instructions

export PATH := /opt/homebrew/bin:$(PATH)

TIMESTAMP := $(shell date +%Y%m%d%H%M%S)

SSH_CONFIG := $(HOME)/.ssh/config
GIT_CONFIG := $(HOME)/.config/git/config
ZSHRC      := $(HOME)/.zshrc

.PHONY: default
default: help

.PHONY: help
help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@echo "  all        Run install, seed, lfs, check"
	@echo "  install    Install Homebrew and packages"
	@echo "  seed       Seed config files from defaults"
	@echo "  lfs        Install Git LFS hooks"
	@echo "  check      Verify SSH key, GPG key, Git signing key"
	@echo "  clean      Back up config files and re-seed"

.PHONY: all
all: install seed lfs check
	@echo ""
	@echo "=== Done ==="
	@echo "Restart your terminal to pick up .zshrc changes."
	@echo "Open nvim to let Lazy install plugins."

# https://brew.sh — https://github.com/Homebrew/homebrew-bundle
.PHONY: install
install:
	@if ! command -v brew >/dev/null 2>&1; then \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
	else \
		echo "OK: Homebrew already installed"; \
		brew update; \
	fi
	brew bundle --file="$(HOME)/Brewfile"
	@if command -v claude >/dev/null 2>&1; then \
		echo "OK: Claude Code already installed"; \
	else \
		curl -fsSL https://claude.ai/install.sh | bash; \
	fi

.PHONY: seed
seed: seed-ssh seed-git seed-zsh

#   $(1) = file path, $(2) = line to include
define ensure-include
	@mkdir -p "$(dir $(1))"
	@if [ -f "$(1)" ] && grep -qF '$(2)' "$(1)"; then \
		echo "OK: $(1) includes $(2)"; \
	elif [ -f "$(1)" ]; then \
		{ printf '%s\n\n' '$(2)'; cat "$(1)"; \
		} > "$(1).tmp" && \
		mv "$(1).tmp" "$(1)" && \
		echo "OK: prepended to existing $(1)"; \
	else \
		printf '%s\n' '$(2)' > "$(1)"; \
		echo "OK: created $(1)"; \
	fi
endef

.PHONY: seed-ssh
seed-ssh:
	$(call ensure-include,$(SSH_CONFIG),Include config.default)

.PHONY: seed-git
seed-git:
	@mkdir -p "$(dir $(GIT_CONFIG))"
	@if [ -f "$(GIT_CONFIG)" ] && grep -qF 'path = config.default' "$(GIT_CONFIG)"; then \
		echo "OK: $(GIT_CONFIG) includes config.default"; \
	elif [ -f "$(GIT_CONFIG)" ]; then \
		{ printf '%s\n' \
			'[include]' \
			'	path = config.default' \
			''; \
		cat "$(GIT_CONFIG)"; \
		} > "$(GIT_CONFIG).tmp" && \
		mv "$(GIT_CONFIG).tmp" "$(GIT_CONFIG)" && \
		echo "OK: prepended include to existing $(GIT_CONFIG)"; \
	else \
		printf '%s\n' \
			'[include]' \
			'	path = config.default' \
			'' \
			'; [user]' \
			';	signingkey = YOUR_KEY_HERE ; gpg --list-secret-keys --keyid-format=long' \
			'; [commit]' \
			';	gpgsign = true' \
			'; [tag]' \
			';	gpgSign = true' \
			'; [includeIf "gitdir:~/Code/Org/"]' \
			';	path = ~/Code/Org/.gitconfig' \
			> "$(GIT_CONFIG)"; \
		echo "OK: created $(GIT_CONFIG)"; \
	fi

.PHONY: seed-zsh
seed-zsh:
	$(call ensure-include,$(ZSHRC),source ~/.zshrc.default)

.PHONY: lfs
lfs:
	git lfs install

.PHONY: check
check: check-ssh check-gpg check-git check-lfs

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
	@if gpg --list-secret-keys --keyid-format=long 2>/dev/null | grep -q '^sec'; then \
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
	@if git config --global user.signingkey >/dev/null 2>&1; then \
		echo "OK: Git signing key configured"; \
	else \
		echo "WARN: No git signing key set. Run: gpg --list-secret-keys --keyid-format=long"; \
		echo "Then add signingkey to ~/.config/git/config"; \
	fi

.PHONY: check-lfs
check-lfs:
	@if git config --global filter.lfs.clean >/dev/null 2>&1; then \
		echo "OK: Git LFS configured"; \
	else \
		echo "WARN: Git LFS not configured. Run: make lfs"; \
	fi

.PHONY: clean
clean:
	@printf "Back up and re-seed ~/.ssh/config, ~/.config/git/config, ~/.zshrc? [y/N] "; \
		read ans; \
		case "$$ans" in [yY]) ;; *) echo "Aborted."; exit 1; esac
	@echo "Backing up configs..."
	@for f in "$(SSH_CONFIG)" "$(GIT_CONFIG)" "$(ZSHRC)"; do \
		if [ -f "$$f" ]; then \
			bak="$$f.bak.$(TIMESTAMP)"; \
			mv "$$f" "$$bak"; \
			echo "  $$f -> $$bak"; \
		fi; \
	done
	@$(MAKE) seed lfs
