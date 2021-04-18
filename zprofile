eval $(/opt/homebrew/bin/brew shellenv)

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

BREW=$(brew --prefix)
export LDFLAGS="-L$BREW/xz/lib -L$BREW/readline/lib -L$BREW/zlib/lib"
export CPPFLAGS="-I$BREW/xz/include -I$BREW/readline/include -I$BREW/zlib/include -I$(xcrun --show-sdk-path)/usr/include"

