#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


#############################
# COPY STUFF
#############################
cp /Users/eferm/Dropbox/env/certs/pt/cert.pem /usr/local/etc/openssl/

mkdir -p /usr/local/etc/openssl/certs/
cp /Users/eferm/Dropbox/env/certs/pt/rootca.pem /usr/local/etc/openssl/certs/
# /usr/local/opt/openssl/bin/c_rehash


#############################
# LOCAL VARIABLES
#############################

BREWPATH=/usr/local/bin:/usr/local/sbin
OPENSSLPATH=/usr/local/opt/openssl/bin
SQLITEPATH=/usr/local/opt/sqlite/bin
MACTEXPATH=/usr/local/texlive/2018/bin/x86_64-darwin

JAVA_HOME_11=$(/usr/libexec/java_home -v11)
# JAVA_HOME_10=$(/usr/libexec/java_home -v10)
JAVA_HOME_9=$(/usr/libexec/java_home -v9)
JAVA_HOME_8=$(/usr/libexec/java_home -v1.8)

PYTHON_BREW_2=/usr/local/opt/python@2/bin
PYTHON_BREW_3=/usr/local/opt/python/libexec/bin

PYTHON_CONDA_3=/usr/local/miniconda3/bin
PYTHON_CONDA_2=/usr/local/miniconda2/bin

CERT_PEM_FILE=/usr/local/etc/openssl/cert.pem
CERT_CRT_FILE=/Users/eferm/Dropbox/env/certs/pt/ca-bundle.crt


#############################
# ENV VARIABLES
#############################

export PS1="\[\e[1m\]\D{%Y-%m-%d %H:%M} \u@\H:\w:$ \[\e[0m\]"
export JAVA_HOME=$JAVA_HOME_8
export GOPATH=$HOME/go

export PATH=/usr/bin:/usr/sbin:/bin:/sbin
export PATH=$BREWPATH:$PATH  # include homebrew
export PATH=$GOPATH/bin:$PATH  # include go
export PATH=$MACTEXPATH:$PATH  # include mactex
PATH_NO_PYTHON=$PATH  # used later for switching python dist
export PATH=$PYTHON_CONDA_3:$PATH  # include preferred python

# python
export WORKON_HOME=/Users/eferm/.virtualenvs

# ssl
export SSL_CERT_FILE=$CERT_PEM_FILE
export CURL_CA_BUNDLE=$CERT_CRT_FILE
export REQUESTS_CA_BUNDLE=$CERT_PEM_FILE
export WEBSOCKET_CLIENT_CA_BUNDLE=$CERT_PEM_FILE
export CPPFLAGS=-I/usr/local/opt/openssl/include
export LDFLAGS=-L/usr/local/opt/openssl/lib
export DYLD_LIBRARY_PATH=/usr/local/opt/openssl/lib

# spark
export SPARK_HOME=`brew info apache-spark | grep /usr | tail -n 1 | cut -f 1 -d " "`/libexec
export PYTHONPATH=$SPARK_HOME/python:$PYTHONPATH
export HADOOP_HOME=`brew info hadoop | grep /usr | head -n 1 | cut -f 1 -d " "`/libexec
export LD_LIBRARY_PATH=$HADOOP_HOME/lib/native/:$LD_LIBRARY_PATH



#############################
# ALIASES
#############################

alias b='cd ..'
alias bb='cd ../..'
alias bbb='cd ../../..'
alias bbbb='cd ../../../..'
alias ls='ls -AGh'
alias ll='ls -AlGh'  # -AlGrth
alias rm='rm -f'
alias google='ping -c 5 google.com'
alias pingwdate='ping -v google.com | while read line; do echo `gdate +%Y-%m-%d\ %H:%M:%S:%N` $line; done'
alias word='sed `perl -e "print int rand(99999)"`"q;d" /usr/share/dict/words'
alias sshkeygen='ssh-keygen -t rsa -b 4096 -C'

# java
alias switch_java_11='export JAVA_HOME=$JAVA_HOME_11'
# alias switch_java_10='export JAVA_HOME=$JAVA_HOME_10'
alias switch_java_9='export JAVA_HOME=$JAVA_HOME_9'
alias switch_java_8='export JAVA_HOME=$JAVA_HOME_8'

# python
alias venv='source venv/bin/activate'
alias switch_python_brew_3='export PATH=$PYTHON_BREW_3:$PATH_NO_PYTHON'
alias switch_python_brew_2='export PATH=$PYTHON_BREW_2:$PATH_NO_PYTHON'
alias switch_python_conda_3='export PATH=$PYTHON_CONDA_3:$PATH_NO_PYTHON'
alias switch_python_conda_2='export PATH=$PYTHON_CONDA_2:$PATH_NO_PYTHON'

alias brew="SSL_CERT_FILE='' CURL_CA_BUNDLE='' brew"
alias requests_proxy_on='export REQUESTS_CA_BUNDLE=$CERT_PEM_FILE'
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

# direnv
cp $DIR/direnvrc ~/.direnvrc


#############################
# EVAL, SOURCE, EXECUTE COMMANDS
#############################

eval "$(direnv hook bash)"
# pip install -U -q virtualenvwrapper
# source /usr/local/bin/virtualenvwrapper.sh

# /usr/local/bin/archey --color

