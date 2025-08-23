#!/bin/bash

# rio config
echo "Retrieving rio config..."

if [ -f ~/.config/rio/config.toml ]; then
	cp ~/.config/rio/config.toml rio/config.toml
fi

# starship config
echo "Retrieving starship config..."

if [ -f ~/.config/starship.toml ]; then
	cp ~/.config/starship.toml starship/starship.toml
fi

# biome config
echo "Retrieving biome config..."

if [ -f ~/biome.json ]; then
	cp ~/biome.json biome/biome.json
fi

# .bashrc
echo "Retrieving .bashrc..."

if [ -f ~/.bashrc ]; then
	cp ~/.bashrc bash/.bashrc
fi

echo "Done."
