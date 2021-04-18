source $HOME/.agnoster.zsh-theme

# completions
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH
fi
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}'

autoload -Uz compinit
compinit

setopt AUTO_CD
setopt EXTENDED_HISTORY
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST 
setopt HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt CORRECT
setopt PROMPT_SUBST

HISTFILE=$HOME/.zsh_history
SAVEHIST=5000
HISTSIZE=2000

alias -g ls='ls -AGp'
alias -g ll='ls -ohL'
alias -g lll='ls -lhO'
alias -g cat='bat --plain --paging=never'
alias b='cd ..'
alias bb='cd ../..'
alias bbb='cd ../../..'
alias -g brew='env PATH="${PATH//$(pyenv root)\/shims:/}" brew'  # https://github.com/pyenv/pyenv/issues/106
alias -g subl='/Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl'
alias -g code='code-insiders'

export LS_COLORS=exfxfeaeBxxehehbadacea
export GPG_TTY=$(tty)

# adds shims to PATH
# adds completions
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi

export PATH="$HOME/.poetry/bin:$PATH"

# pip should only run if there is a virtualenv currently activated
export PIP_REQUIRE_VIRTUALENV=true
 
# commands to override pip restriction above.
# use `gpip` or `gpip3` to force installation of
# a package in the global python environment
# Never do this! It is just an escape hatch.
gpip(){
   PIP_REQUIRE_VIRTUALENV="" pip "$@"
}
gpip3(){
   PIP_REQUIRE_VIRTUALENV="" pip3 "$@"
}

