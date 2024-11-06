#!/usr/bin/env sh

echo "Updating the yadm repo origin URL"
yadm remote set-url origin "https://github.com/pedropombeiro/dotfiles.git"
yadm remote set-url --push origin "git@github.com:pedropombeiro/dotfiles.git"
