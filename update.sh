#!/bin/bash

# rio config
echo "Copying rio config..."

mkdir -p ~/.config/rio/themes

cp rio/config.toml ~/.config/rio/config.toml
cp rio/themes/catppuccin-macchiato.toml ~/.config/rio/themes/catppuccin-macchiato.toml

# starship config
echo "Copying starship config..."

cp starship/starship.toml ~/.config/starship.toml

# biome config
echo "Copying biome config..."

cp biome/biome.json ~/biome.json

# dependencies
echo "Checking dependencies..."

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
    sudo pacman -Sy ripgrep
fi

# init ripgrep
if ! grep -q 'alias grep' ~/.bashrc; then
    echo "Adding ripgrep alias..."
    echo 'alias grep="rg"' >> ~/.bashrc
fi

echo "Done."
