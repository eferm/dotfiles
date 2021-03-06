#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


#############################
# LOCAL VARIABLES
#############################

BREWPATH=/usr/local/bin:/usr/local/sbin
OPENSSLPATH=/usr/local/opt/openssl/bin
SQLITEPATH=/usr/local/opt/sqlite/bin
MACTEXPATH=/usr/local/texlive/2019/bin/x86_64-darwin
RUSTPATH=/Users/eferm/.cargo/bin
#JAVA_HOME_11=$(/usr/libexec/java_home -v11)
#JAVA_HOME_9=$(/usr/libexec/java_home -v9)
JAVA_HOME_8=$(/usr/libexec/java_home -v1.8)

# optional python installs
PYTHON_BREW_2=/usr/local/opt/python@2/bin
PYTHON_BREW_3=/usr/local/opt/python/libexec/bin
CONDA_3=/opt/miniconda3/bin
POETRYPATH=/Users/eferm/.poetry/bin

parse_git_branch() {
     git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}


#############################
# ENV VARIABLES
#############################

#export PS1="\[\e[1m\]\D{%Y-%m-%d %H:%M} \u@\H:\w:$ \[\e[0m\]"
export PS1="\u@\h \[\033[32m\]\w\[\033[33m\]\$(parse_git_branch)\[\033[00m\] $ "
export JAVA_HOME=$JAVA_HOME_8
export GOPATH=$HOME/go
export GPG_TTY=$(tty)
#export NPM_CONFIG_REGISTRY=https://artifactory.palantir.build/artifactory/api/npm/all-npm/

#export LDFLAGS="-L$(brew --prefix readline)/lib -L$(brew --prefix openssl)/lib -L$(brew --prefix zlib)/lib"
#export CFLAGS="-I$(brew --prefix readline)/include -I$(brew --prefix openssl)/include -I$(brew --prefix zlib)/include -I$(xcrun --show-sdk-path)/usr/include"
#export CPPFLAGS=$CFLAGS

#export SSL_CERT_FILE=/Users/eferm/Dropbox/env/certs/cacert.pem
#cp $SSL_CERT_FILE /usr/local/etc/openssl/
#mkdir -p /usr/local/etc/openssl/certs/
#cp $SSL_CERT_FILE /usr/local/etc/openssl/certs/

export PATH=/usr/bin:/usr/sbin:/bin:/sbin
export PATH=$BREWPATH:$PATH  # include homebrew
#export PATH=$GOPATH/bin:$PATH  # include go
export PATH=$MACTEXPATH:$PATH  # include mactex
export PATH=$CONDA_3:$PATH
export PATH=$PYTHON_BREW_3:$PATH  # include python
export PATH=$RUSTPATH:$PATH
export PATH=$POETRYPATH:$PATH  # include poetry

# spark
# export SPARK_HOME=`brew info apache-spark | grep /usr | tail -n 1 | cut -f 1 -d " "`/libexec
# export HADOOP_HOME=`brew info hadoop | grep /usr | head -n 1 | cut -f 1 -d " "`/libexec
export SPARK_HOME=/usr/local/Cellar/apache-spark/3.0.0/libexec
#export HADOOP_HOME=/usr/local/Cellar/hadoop/3.1.1/libexec
export PYTHONPATH=$SPARK_HOME/python:.:$PYTHONPATH
export LD_LIBRARY_PATH=$HADOOP_HOME/lib/native/:$LD_LIBRARY_PATH
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES  # https://stackoverflow.com/a/55379370


#############################
# ALIASES
#############################

# overrides
alias ls='ls -Agh'
alias rm='rm -f'
alias ping='ping -c 100'
#alias brew="SSL_CERT_FILE='' CURL_CA_BUNDLE='' brew"
alias pipenv='PIPENV_VENV_IN_PROJECT=1 pipenv'
alias archey='archey --offline'

# convenience
alias b='cd ..'
alias bb='cd ../..'
alias bbb='cd ../../..'
alias bbbb='cd ../../../..'
alias ll='ls -AlGh'  # -AlGrth
alias google='ping -c 5 google.com'
alias pingwdate='ping -v google.com | while read line; do echo `gdate +%Y-%m-%d\ %H:%M:%S:%N` $line; done'
alias word='sed `perl -e "print int rand(99999)"`"q;d" /usr/share/dict/words'
alias checksum='shasum -a 256'
alias rand='jot -r 1 1 101'
alias scanner='convert -density 200 ORIGINAL.pdf -colorspace gray +noise Gaussian -rotate 0.5 -depth 2 SCANNED.pdf'
alias strippdf='exiftool -all= input.pdf && qpdf --linearize --replace-output input.pdf'

# java
alias switch_java_11='export JAVA_HOME=$JAVA_HOME_11'
alias switch_java_9='export JAVA_HOME=$JAVA_HOME_9'
alias switch_java_8='export JAVA_HOME=$JAVA_HOME_8'

# python
alias pip_outdated="pip list --outdated --pre"
alias pip_upgrade_all='pip list --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip install -U'
alias pip_uninstall_all='pip freeze | xargs pip uninstall -y'
alias pip_freeze="pip freeze > requirements.txt && sed -i '' -e 's/==/>=/g' requirements.txt"


#############################
# FUNCTIONS
#############################

function pdfstrip(){
  exiftool -all= $1
	qpdf --linearize --replace-input $1
}

function pdfscanner(){
	mv $1 "$1_original"
	convert -density 150 "$1_original" -colorspace gray +noise Gaussian -rotate 0.5 -depth 2 $1
}

#############################
# RESET DOT CONFIGS
#############################

# vim
mkdir -p ~/.vim/colors
mkdir -p ~/.vim/tmp  # required for swp file config
cp $DIR/vim/colors/solarized.vim ~/.vim/colors
cp $DIR/vimrc ~/.vimrc

# ssh
cp $DIR/ssh/config ~/.ssh/config

# direnv
cp $DIR/direnvrc ~/.direnvrc


#############################
# EVAL, SOURCE, EXECUTE COMMANDS
#############################

eval "$(pyenv init -)"
#pyenv global 3.6.8

