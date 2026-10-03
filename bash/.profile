# ~/.profile
# by coalaura

if [ -f "$HOME/.shenv" ]; then
    . "$HOME/.shenv"
fi

if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi
