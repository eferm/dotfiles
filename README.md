# New Mac Setup Guide

Highly opinionated personal preferences minimum viable setup.

This guide only known to be compatible with MacOS Monterey (version 12).


### Table of Contents:

1. [Configure System](#configure-system)
    1. [Hostname](#system-hostname)
    1. [Homebrew](#system-homebrew)
    1. [Zsh](#system-zsh)
    1. [Vim](#system-vim)
    1. [GPG](#system-gpg)
    1. [SSH](#system-ssh)
    1. [Git](#system-git)
1. [Configure Themes](#configure-themes)
    1. [Font](#themes-font)
    1. [Terminal](#themes-terminal)
    1. [Zsh](#themes-zsh)
    1. [Vim](#themes-vim)
    1. [Sublime Text](#themes-sublime-text)
    1. [Visual Studio Code](#themes-visual-studio-code)


## Configure System

### Hostname <a name="system-hostname"></a>

Clean up hostname and computer name [[apple.stackexchange.com](https://apple.stackexchange.com/a/287775)]

1. Run commands:

    ```bash
    sudo scutil --set HostName <mymac>
    ```
    ```bash
    sudo scutil --set LocalHostName <MyMac>
    ```
    ```bash
    sudo scutil --set ComputerName <MyMac>
    ```

1. Flush the DNS cache:

    ```bash
    dscacheutil -flushcache
    ```

1. Restart Mac


### Homebrew <a name="system-homebrew"></a>

1. Install Homebrew [[brew.sh](https://brew.sh/)]:

    ```bash
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ```

1. Install packages:

    ```bash
    /opt/homebrew/bin/brew install gnupg pyenv poetry sublime-text visual-studio-code
    ```


### Zsh <a name="system-zsh"></a>

Ref: [[scriptingosx.com](https://scriptingosx.com/zsh/)]

1. Add the following to `~/.zprofile`:

    ```bash
    eval "$(/opt/homebrew/bin/brew shellenv)"
    eval "$(pyenv init --path)"
    ```

1. Add the following to `~/.zshrc`:

    ```bash
    if type brew &>/dev/null; then
       FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH
    fi

    fpath+=~/.zfunc
    zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}'
    autoload -Uz compinit
    compinit

    setopt PROMPT_SUBST

    alias ls='ls -Gp'
    alias l='ls -ohL'
    alias ll='ls -AohL'
    alias lll='ls -AlhO'

    export LS_COLORS=exfxfeaeBxxehehbadacea
    
    eval "$(pyenv init -)"
    ```

1. Run commands:

    ```bash
    mkdir ~/.zfunc && poetry completions zsh > ~/.zfunc/_poetry
    ```
    ```bash
    chmod -R go-w '/opt/homebrew/share'
    ```
    ```bash
    rm -f ~/.zcompdump
    ```

1. Restart Terminal


### Vim <a name="system-vim"></a>

1. Add the following to `~/.vimrc`:

    ```
    set number
    set t_Co=16
    set re=0

    syntax on
    ```

1. Install the `vim-plug` plugin
[[GitHub](https://github.com/junegunn/vim-plug)]:

    ```bash
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    ```


### GPG <a name="system-gpg"></a>

Import GPG keys [[serverfault.com](https://serverfault.com/a/1040984)]

1. Download keys and ownertrust files:
    - `username@example.com.pub.asc`
    - `username@example.com.priv.asc`
    - `username@example.com.sub_priv.asc`
    - `ownertrust.txt`

1. Import keys by running commands:

    ```bash
    gpg --import username@example.com.pub.asc
    ```
    ```bash
    gpg --import username@example.com.priv.asc
    ```
    ```bash
    gpg --import username@example.com.sub_priv.asc
    ```
    ```bash
    gpg --import-ownertrust ownertrust.txt
    ```

1. Trust keys by running commands:

    ```bash
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

1. Generate new SSH key:

    ```bash
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

        ```bash
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

        ```bash
        ssh-add --apple-use-keychain ~/.ssh/id_ed25519
        ```

1. Add the SSH **public** key to GitHub:

    1. Copy the key to your clipboard:

        ```bash
        pbcopy < ~/.ssh/id_ed25519.pub
        ```

    1. In GitHub → Profile → Settings → SSH and GPG keys, click _New SSH key_
    and paste the key.


### Git <a name="system-git"></a>

1. Run commands:

    ```bash
    git config --global user.name "Firstname Lastname"
    ```
    ```bash
    git config --global user.email "username@example.com"
    ```
    ```bash
    git config --global commit.gpgsign true
    ```


## Configure Themes


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

    ```bash
    source $HOME/.agnoster.zsh-theme
    ```


### Vim <a name="themes-vim"></a>

1. Run `vim ~/.vimrc` and append the following:

    ```
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
