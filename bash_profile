#!/bin/bash

DIR="/Users/eferm/Dropbox/code/dotfiles"

#############################
# CUSTOM VARIABLES
#############################

export JAVA_HOME_8=$(/usr/libexec/java_home -v1.8)
export JAVA_HOME_9=$(/usr/libexec/java_home -v9)

export PYTHON_BREW=/usr/local/opt/python/libexec/bin
export PYTHON_CONDA_2=/usr/local/miniconda2/bin
export PYTHON_CONDA_3=/usr/local/miniconda3/bin

export SSL_CA_BUNDLE=/Users/eferm/Dropbox/env/certs/ca-bundle.crt


#############################
# ENV VARIABLES
#############################

export PS1="\[\e[1m\]\D{%Y-%m-%d %H:%M} \u@\H:\w:$ \[\e[0m\]"
export REQUESTS_CA_BUNDLE=$SSL_CA_BUNDLE
export JAVA_HOME=$JAVA_HOME_9
export PIP_FORMAT=columns

export RESET_PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin
export PATH=$PYTHON_CONDA_3:$RESET_PATH


#############################
# ALIASES
#############################

alias b='cd ..'
alias bb='cd ../..'
alias bbb='cd ../../..'
alias ls='ls -AGh'
alias ll='ls -AlGh' # -AlGrth
alias rm='rm -f'
alias google='ping -c 5 google.com'
alias word='sed `perl -e "print int rand(99999)"`"q;d" /usr/share/dict/words'
alias sshkeygen='ssh-keygen -t rsa -b 4096 -C "gemore@gmail.com"'

# java
alias java_8='export JAVA_HOME=$JAVA_HOME_8'
alias java_9='export JAVA_HOME=$JAVA_HOME_9'

# python
alias python_brew='export PATH=$PYTHON_BREW:$RESET_PATH'
alias python_conda_2='export PATH=$PYTHON_CONDA_2:$RESET_PATH'
alias python_conda_3='export PATH=$PYTHON_CONDA_3:$RESET_PATH'

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
