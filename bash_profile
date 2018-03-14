#!/bin/bash

#############################
# LOCAL VARIABLES
#############################

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # https://stackoverflow.com/q/59895

PATH_BASE=/usr/bin:/usr/sbin:/bin:/sbin
PATH_BREW=/usr/local/bin:/usr/local/sbin
PATH_BREW_BASE=$PATH_BREW:$PATH_BASE

JAVA_HOME_9=$(/usr/libexec/java_home -v9)
JAVA_HOME_8=$(/usr/libexec/java_home -v1.8)

PYTHON_BREW_2=/usr/local/opt/python@2/bin
PYTHON_BREW_3=/usr/local/opt/python/libexec/bin

PYTHON_CONDA_3=/usr/local/miniconda3/bin
PYTHON_CONDA_2=/usr/local/miniconda2/bin

SSL_CA_BUNDLE=/Users/eferm/Dropbox/env/certs/ca-bundle.crt


#############################
# ENV VARIABLES
#############################

export PS1="\[\e[1m\]\D{%Y-%m-%d %H:%M} \u@\H:\w:$ \[\e[0m\]"
export REQUESTS_CA_BUNDLE=$SSL_CA_BUNDLE
export JAVA_HOME=$JAVA_HOME_9
export PIP_FORMAT=columns
export PATH=$PYTHON_CONDA_3:$PATH_BREW_BASE

#############################
# ALIASES
#############################

alias b='cd ..'
alias bb='cd ../..'
alias bbb='cd ../../..'
alias bbbb='cd ../../../..'
alias ls='ls -AGh'
alias ll='ls -AlGh' # -AlGrth
alias rm='rm -f'
alias google='ping -c 5 google.com'
alias word='sed `perl -e "print int rand(99999)"`"q;d" /usr/share/dict/words'
alias sshkeygen='ssh-keygen -t rsa -b 4096 -C'

# brew
alias brew_on='export PATH=$PATH_BREW_BASE'
alias brew_off='export PATH=$PATH_BASE'

# java
alias java_9='export JAVA_HOME=$JAVA_HOME_9'
alias java_8='export JAVA_HOME=$JAVA_HOME_8'

# python
alias python_osx='export PATH=$PATH_BASE:$PATH_BREW'
alias python_brew_3='export PATH=$PYTHON_BREW_3:$PATH_BREW_BASE'
alias python_brew_2='export PATH=$PYTHON_BREW_2:$PATH_BREW_BASE'
alias python_conda_3='export PATH=$PYTHON_CONDA_3:$PATH_BREW_BASE'
alias python_conda_2='export PATH=$PYTHON_CONDA_2:$PATH_BREW_BASE'

alias requests_proxy_on='export REQUESTS_CA_BUNDLE=$SSL_CA_BUNDLE'
alias requests_proxy_off='export REQUESTS_CA_BUNDLE='

alias pip_upgrade_all='pip list --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip install -U'
alias pip_uninstall_all='pip freeze | xargs pip uninstall -y'
alias pip_freeze="pip freeze > requirements.txt && sed -i '' -e 's/==/>=/g' requirements.txt"


#############################
# RESET DOT CONFIGS
#############################

# vim
mkdir -p ~/.vim/colors
cp $DIR/vim/colors/solarized.vim ~/.vim/colors
cp $DIR/vimrc ~/.vimrc

# ssh
cp $DIR/ssh/config ~/.ssh/config

# python
mkdir -p ~/.pip
cp $DIR/pip/pip.conf ~/.pip/pip.conf


#############################
# EXECUTE COMMANDS
#############################

eval "$(direnv hook bash)"
/usr/local/bin/archey --color
