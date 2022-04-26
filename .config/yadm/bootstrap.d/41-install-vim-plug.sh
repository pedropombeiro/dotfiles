#!/usr/bin/env bash

YADM_SCRIPTS=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/../scripts" &> /dev/null && pwd )

source "${YADM_SCRIPTS}/colors.sh"

if [ "$(command -v vim)" -o "$(command -v nvim)" ]; then
  if [[ ! -f "${HOME}/.vim/autoload/plug.vim" ]]; then
    printf "${YELLOW}%s${NC}\n" 'Installing vim-plug...'
    curl -fLo "${HOME}/.vim/autoload/plug.vim" --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  fi

  printf "${YELLOW}%s${NC}\n" 'Installing vim plugins...'
  nvim --headless -c 'PlugInstall | qa!'
fi

