#!/bin/bash

# rio config
cp -r rio ~/.config/rio

# starship config
cp -r starship/starship.toml ~/.config/starship.toml

# install starship
if ! command -v starship >/dev/null 2>&1; then
    echo "Installing starship..."
    curl -sS https://starship.rs/install.sh | sh
fi

# init starship
if ! grep -q 'starship init bash' ~/.bashrc; then
    echo "Adding starship init..."
    echo 'eval "$(starship init bash)"' >> ~/.bashrc
fi

# install ripgrep
if ! command -v rg >/dev/null 2>&1; then
    echo "Installing ripgrep..."
    sudo apt-get install ripgrep -y
fi

# init ripgrep
if ! grep -q 'alias grep' ~/.bashrc; then
    echo "Adding ripgrep alias..."
    echo 'alias grep="rg"' >> ~/.bashrc
fi

# install xh
if ! command -v xh >/dev/null 2>&1; then
    echo "Installing xh..."
    curl -sfL https://raw.githubusercontent.com/ducaale/xh/master/install.sh | sh
fi

# init xh
if ! grep -q 'alias http' ~/.bashrc; then
    echo "Adding xh alias..."
    echo 'alias http="xh"' >> ~/.bashrc
fi

# install neofetch
if ! command -v neofetch >/dev/null 2>&1; then
    echo "Installing neofetch..."
    sudo apt install neofetch -y
fi
