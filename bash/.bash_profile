#!/bin/bash
# ~/.bash_profile
# by coalaura

if [ -f "$HOME/.shenv" ]; then
    . "$HOME/.shenv"
fi

if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi
