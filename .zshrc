export PATH="/opt/homebrew/bin:$PATH"
export XDG_CONFIG_HOME="$HOME/.config"
export LS_COLORS="$(vivid generate tokyonight-night)"
export RIPGREP_CONFIG_PATH="$HOME/.ripgreprc"

alias ls='gls -Nh --color --dereference-command-line --group-directories-first'
alias l='ls -Lo'
alias ll='ls -LoA'
alias lll='ls -lA'
alias b='cd ..'
alias bb='cd ../..'
alias bbb='cd ../../..'
alias dotfiles='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
alias lazydot='lazygit --git-dir=$HOME/.dotfiles --work-tree=$HOME'
alias filecounts='du -a | cut -d/ -f2 | sort | uniq -c | sort -nr'

eval "$(starship init zsh)"

source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

