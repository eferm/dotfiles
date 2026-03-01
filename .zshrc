# brew install coreutils starship zsh-syntax-highlighting zsh-autosuggestions font-fira-code-nerd-font vivid
# starship preset nerd-font-symbols -o ~/.config/starship.toml

export PATH="/opt/homebrew/bin:$PATH"
export LS_COLORS="$(vivid generate snazzy)"
export RIPGREP_CONFIG_PATH="$HOME/.ripgreprc"
export XDG_CONFIG_HOME="$HOME/.config"

alias ls='gls -Nh --color --dereference-command-line --group-directories-first'
alias l='ls -Lo'
alias ll='ls -LoA'
alias lll='ls -lA'
alias b='cd ..'
alias bb='cd ../..'
alias bbb='cd ../../..'
alias dotfiles='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
alias filecounts='du -a | cut -d/ -f2 | sort | uniq -c | sort -nr'
alias sshclaude='ssh eferm@j773 -t tmux attach -t claude'

eval "$(starship init zsh)"

source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

function print_osc7() {
  printf "\033]7;file://$HOSTNAME$PWD\033\\"
}
chpwd_functions+=(print_osc7)
print_osc7  # emit on shell startup too
