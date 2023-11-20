#!/bin/bash
# Run install script on boot

if [ -f ~/Downloads/dotfiles/install.sh ]; then
    ~/Downloads/dotfiles/install.sh
elif [ -f ~/dotfiles/install.sh ]; then
    ~/dotfiles/install.sh
elif [ -f ~/.config/dotfiles/install.sh ]; then
    ~/.config/dotfiles/install.sh

elif [ -f ~/Downloads/dotfiles/script.sh ]; then
    ~/Downloads/dotfiles/script.sh
elif [ -f ~/dotfiles/script.sh ]; then
    ~/dotfiles/script.sh
elif [ -f ~/.config/dotfiles/script.sh ]; then
    ~/.config/dotfiles/script.sh

elif [ -f ~/Downloads/dotfiles/install-script.sh ]; then
    ~/Downloads/dotfiles/install-script.sh
elif [ -f ~/dotfiles/install-script.sh ]; then
    ~/dotfiles/install-script.sh
elif [ -f ~/.config/dotfiles/install-script.sh ]; then
    ~/.config/dotfiles/install-script.sh

elif [ -f ~/Downloads/dotfiles/install_script.sh ]; then
    ~/Downloads/dotfiles/install_script.sh
elif [ -f ~/dotfiles/install_script.sh ]; then
    ~/dotfiles/install_script.sh
elif [ -f ~/.config/dotfiles/install_script.sh ]; then
    ~/.config/dotfiles/install_script.sh
fi
