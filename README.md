# New Mac Setup Guide

Highly opinionated personal preferences minimum viable setup.

This guide only known to be compatible with MacOS Monterey (version 12).


### Table of Contents:

1. [Configure System](#configure-system)
    1. [Hostname](#system-hostname)
    2. [Homebrew](#system-homebrew)
    3. [Zsh](#system-zsh)
    5. [Vim](#system-vim)
    6. [GPG](#system-gpg)
    7. [SSH](#system-ssh)
    8. [Git](#system-git)
2. [Configure Themes](#configure-themes)
    1. [Font](#themes-font)
    2. [Terminal](#themes-terminal)
    3. [Zsh](#themes-zsh)
    4. [Vim](#themes-vim)
    5. [Sublime Text](#themes-sublime-text)
    6. [Visual Studio Code](#themes-visual-studio-code)


## Configure System

### Hostname <a name="system-hostname"></a>

Configure hostname and computer name [[apple.stackexchange.com](https://apple.stackexchange.com/a/287775)]

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

 2. Flush the DNS cache:

    ```bash
    dscacheutil -flushcache
    ```

 3. Restart Mac


### Homebrew <a name="system-homebrew"></a>

1. Install Homebrew [[brew.sh](https://brew.sh/)]:

    ```bash
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ```

2. Install packages:

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

2. Add the following to `~/.zshrc`:

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

3. Run commands:

    ```bash
    mkdir ~/.zfunc && poetry completions zsh > ~/.zfunc/_poetry
    ```
    ```bash
    chmod -R go-w '/opt/homebrew/share'
    ```
    ```bash
    rm -f ~/.zcompdump
    ```

4. Restart Terminal


### Vim <a name="system-vim"></a>

1. Add the following to `~/.vimrc`:

    ```
    set number
    set t_Co=16
    set re=0

    syntax on
    ```

2. Install the `vim-plug` plugin
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

2. Import keys by running commands:

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

3. Trust keys by running commands:

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

2. Add your SSH key to the `ssh-agent`:

    1. Start SSH agent:

        ```bash
        eval "$(ssh-agent -s)"
        ```
        Output:
        ```
        > Agent pid 12345
        ```

    2. Run `vim ~/.ssh/config` and add the following:

        ```
        Host *
          AddKeysToAgent yes
          IdentityFile ~/.ssh/id_ed25519
        ```

  3. Add you SSH private key to the `ssh-agent`:

        ```bash
        ssh-add --apple-use-keychain ~/.ssh/id_ed25519
        ```

3. Add the SSH **public** key to GitHub:

    1. Copy the key to your clipboard:

        ```bash
        pbcopy < ~/.ssh/id_ed25519.pub
        ```

    2. In GitHub → Profile → Settings → SSH and GPG keys, click _New SSH key_
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

1. Download and install _Droid Sans Mono Dotted for Powerline_
[[GitHub](https://github.com/powerline/fonts)]


### Terminal <a name="themes-terminal"></a>

1. Download and install the `Nord.terminal` theme
[[GitHub](https://github.com/arcticicestudio/nord-terminal-app/releases)]
    - Click _Default_

2. Change font to _Droid Sans Mono Dotted for Powerline_:
    - Font Weight: Regular
    - Font Size: 11pt
    - Character Spacing: 1
    - Line Spacing: 0.885


### Zsh <a name="themes-zsh"></a>

1. Download the `agnoster.zsh-theme` theme to `~/.agnoster.zsh-theme`
[[GitHub](https://github.com/agnoster/agnoster-zsh-theme)]

2. Edit `.zshrc` and add the following line at the top of the file:

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

2. Still in `vim` run: `:PlugInstall`

3. `:wq` to save and exit `vim`


### Sublime Text <a name="themes-sublime-text"></a>

1. Run `Shift+Cmd+P` → Install Package → `Nord`

2. Run `Shift+Cmd+P` → Preferences: Settings, and add:

    ```json
    "theme": "Adaptive.sublime-theme",
    "color_scheme": "Nord.sublime-color-scheme",
    "font_face": "Droid Sans Mono Dotted for Powerline",
    "font_size": 12,
    "line_numbers": true,
    ```


### Visual Studio Code <a name="themes-visual-studio-code"></a>

1. Install the `Nord Deep` extension

2. Run `Shift+Cmd+P` → Open Settings (JSON), and add:

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
