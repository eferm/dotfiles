# New Mac Setup Guide

Highly opinionated personal preferences minimum viable setup.

This guide only known to be compatible with MacOS Monterey (version 12)
on an M1 Mac.


### Table of Contents:

1. [Configure System](#configure-system)
    1. [Hostname](#system-hostname)
    1. [Terminal](#system-terminal)
    1. [Homebrew](#system-homebrew)
    1. [Zsh](#system-zsh)
    1. [Vim](#system-vim)
    1. [GPG](#system-gpg)
    1. [SSH](#system-ssh)
    1. [Git](#system-git)
    1. [Python](#system-python)
    1. [Java](#system-java)
1. [Configure Themes](#configure-themes)
    1. [Font](#themes-font)
    1. [Terminal](#themes-terminal)
    1. [Zsh](#themes-zsh)
    1. [Vim](#themes-vim)
    1. [Sublime Text](#themes-sublime-text)
    1. [Visual Studio Code](#themes-visual-studio-code)


## Configure System

### Hostname (Optional) <a name="system-hostname"></a>

Clean up hostname and computer name
[[apple.stackexchange.com](https://apple.stackexchange.com/a/287775)]

1. Run commands:

    ```shell
    sudo scutil --set HostName <mymac>
    ```
    ```shell
    sudo scutil --set LocalHostName <MyMac>
    ```
    ```shell
    sudo scutil --set ComputerName <MyMac>
    ```

1. Flush the DNS cache:

    ```shell
    dscacheutil -flushcache
    ```

1. Restart Mac


### Terminal <a name="system-terminal"></a>

1. Create a copy of `/Applications/Utilities/Terminal.app` called
`Rosetta Terminal.app` and set the _Open using Rosetta_ option in _Get Info_.


### Homebrew <a name="system-homebrew"></a>

1. Install Homebrew [[brew.sh](https://brew.sh/)]:

    ```shell
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ```
    Run the same command also in _Rosetta Terminal_.

1. Install packages:

    ```shell
    /opt/homebrew/bin/brew install gnupg pyenv poetry sublime-text visual-studio-code
    ```
    In _Rosetta Terminal_ also run:
    ```shell
    /usr/local/bin/brew install pyenv
    ```


### Zsh <a name="system-zsh"></a>

Ref: [[scriptingosx.com](https://scriptingosx.com/zsh/)]

1. Add the following to `~/.zprofile`:

    ```shell
    echo $(arch)

    if [ $(arch) = 'i386' ]; then
        eval "$(/usr/local/bin/brew shellenv)"
        export PYENV_ROOT="${HOME}/.pyenv_x86"
    else
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    eval "$(pyenv init --path)"
    ```

1. Add the following to `~/.zshrc`:

    ```shell
    if type brew &>/dev/null; then
       FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH
    fi

    fpath+=~/.zfunc
    autoload -Uz compinit && compinit
    zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

    setopt PROMPT_SUBST

    alias ls='ls -Gp'
    alias l='ls -ohL'
    alias ll='ls -AohL'
    alias lll='ls -AlhO'
    alias b='cd ..'
    alias bb='cd ../..'
    alias bbb='cd ../../..'
    # https://github.com/pyenv/pyenv/issues/106#issuecomment-94921352
    alias brew="env PATH=${PATH//$(pyenv root)\/shims:/} brew"

    export LS_COLORS=exfxfeaeBxxehehbadacea
    
    if [ $(arch) = 'i386' ]; then
        export PYENV_ROOT="${HOME}/.pyenv_x86"
    fi
    eval "$(pyenv init -)"
    ```

1. Run commands:

    ```shell
    mkdir ~/.zfunc && poetry completions zsh > ~/.zfunc/_poetry
    ```
    ```shell
    chmod -R go-w '/opt/homebrew/share'
    ```
    ```shell
    rm -f ~/.zcompdump
    ```

1. Restart Terminal


### Vim <a name="system-vim"></a>

1. Add the following to `~/.vimrc`:

    ```vim
    set number
    set t_Co=16
    set re=0

    syntax on
    ```

1. Install the `vim-plug` plugin
[[GitHub](https://github.com/junegunn/vim-plug)]:

    ```shell
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    ```


### GPG <a name="system-gpg"></a>

Import GPG keys [[serverfault.com](https://serverfault.com/a/1040984)]

1. Copy keys and ownertrust files from your backup:
    - `username@example.com.pub.asc`
    - `username@example.com.priv.asc`
    - `username@example.com.sub_priv.asc`
    - `ownertrust.txt`

1. Import keys by running commands:

    ```shell
    gpg --import username@example.com.pub.asc
    ```
    ```shell
    gpg --import username@example.com.priv.asc
    ```
    ```shell
    gpg --import username@example.com.sub_priv.asc
    ```
    ```shell
    gpg --import-ownertrust ownertrust.txt
    ```

1. Trust keys by running commands:

    ```shell
    gpg --edit-key username@example.com
    ```
    Output:
    ```
    > gpg> trust
    > Your decision? 5
    > gpg> quit
    ```


### SSH <a name="system-ssh"></a>

Configure SSH keys and agent [[github.com](https://docs.github.com/en/authentication)]

1. Generate new SSH key (use corp. email on corp. laptop):

    ```shell
    ssh-keygen -t ed25519 -C "username@example.com"
    ```
    Output:
    ```
    > ...
    > Enter passphrase (empty for no passphrase): <empty>
    > ...
    ```

1. Add your SSH key to the `ssh-agent`:

    1. Start SSH agent:

        ```shell
        eval "$(ssh-agent -s)"
        ```
        Output:
        ```
        > Agent pid 12345
        ```

    1. Run `vim ~/.ssh/config` and add the following:

        ```
        Host *
            AddKeysToAgent yes
            IdentityFile ~/.ssh/id_ed25519
        ```

    1. Add you SSH private key to the SSH agent:

        ```shell
        ssh-add --apple-use-keychain ~/.ssh/id_ed25519
        ```

1. Add the SSH **public** key to GitHub:

    1. Copy the key to your clipboard:

        ```shell
        pbcopy < ~/.ssh/id_ed25519.pub
        ```

    1. In GitHub → Profile → Settings → SSH and GPG keys, click _New SSH key_
    and paste the key.
    
    1. For corp. emails make sure to also add these to your GitHub account.


### Git <a name="system-git"></a>

1. Run commands (use corp. email for corp. laptop):

    ```shell
    git config --global user.name "Firstname Lastname"
    ```
    ```shell
    git config --global user.email "username@example.com"
    ```
    ```shell
    git config --global commit.gpgsign true
    ```


### Python <a name="system-python"></a>

1. Install a default Python dist:

    ```shell
    pyenv install 3.8.13
    ```
    ```shell
    pyenv global 3.8.13
    ```
    Run the same commands also in _Rosetta Terminal_.


### Java <a name="system-java"></a>

1. Install the latest JDK:

    ```shell
    brew install java
    ```

1. Symlink so MacOS can find the JDK [[mkyong.com](https://mkyong.com/java/how-to-install-java-on-mac-osx/)]

    ```shell
    sudo ln -sfn /opt/homebrew/opt/openjdk/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk.jdk
    ```


## Configure Themes

Preference for the [Nord Theme](https://www.nordtheme.com/).


### Font <a name="themes-font"></a>

1. Download and install `Droid Sans Mono Dotted for Powerline.ttf`
[[GitHub](https://github.com/powerline/fonts)]


### Terminal <a name="themes-terminal"></a>

1. Download and install the `Nord.terminal` theme
[[GitHub](https://github.com/arcticicestudio/nord-terminal-app/releases)]
    - Click _Default_

1. Change font to _Droid Sans Mono Dotted for Powerline_:
    - Font Weight: Regular
    - Font Size: 11pt
    - Character Spacing: 1
    - Line Spacing: 0.885


### Zsh <a name="themes-zsh"></a>

1. Download the `agnoster.zsh-theme` to `~/.agnoster.zsh-theme`
[[GitHub](https://github.com/agnoster/agnoster-zsh-theme)]

1. Edit `.zshrc` and add the following line at the top of the file:

    ```shell
    source $HOME/.agnoster.zsh-theme
    ```


### Vim <a name="themes-vim"></a>

1. Run `vim ~/.vimrc` and append the following:

    ```vim
    call plug#begin(expand('~/.vim/plugged'))
    Plug 'arcticicestudio/nord-vim'
    call plug#end()

    colorscheme nord
    ```

1. Still in `vim` run: `:PlugInstall`

1. Save and exit `vim`


### Sublime Text <a name="themes-sublime-text"></a>

1. Run `Shift+Cmd+P` → Install Package → `Nord`

1. Run `Shift+Cmd+P` → Preferences: Settings, and add:

    ```json
    "theme": "Adaptive.sublime-theme",
    "color_scheme": "Nord.sublime-color-scheme",
    "font_face": "Droid Sans Mono Dotted for Powerline",
    "font_size": 12,
    "line_numbers": true,
    ```


### Visual Studio Code <a name="themes-visual-studio-code"></a>

1. Install the `Nord Deep` extension

1. Run `Shift+Cmd+P` → Open Settings (JSON), and add:

    ```json
    "workbench.colorTheme": "Nord Deep",
    "editor.fontFamily": "Droid Sans Mono Dotted for Powerline",
    "editor.fontSize": 12,
    "editor.fontLigatures": true,
    "terminal.integrated.fontFamily": "Droid Sans Mono Dotted for Powerline",
    "terminal.integrated.fontSize": 12,
    "terminal.integrated.profiles.osx": {
       "zsh": {"path": "/bin/zsh", "args": ["-c", "/bin/zsh"]}
    },
    ```
