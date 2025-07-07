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