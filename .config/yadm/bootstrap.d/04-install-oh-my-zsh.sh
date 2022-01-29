#!/usr/bin/env bash

function install_zsh_plugin() {
  local repo="$1"
  local path="$2"
  if [[ ! -d "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/${path}" ]]; then
    git clone --depth=1 https://github.com/${repo}.git "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/${path}"
  fi
}

grep '.bash_profile.shared' ~/.bash_profile >/dev/null 2>&1|| echo "source ~/.bash_profile.shared" >> ~/.bash_profile
grep '.bashrc.shared' ~/.bashrc >/dev/null 2>&1 || echo "source ~/.bashrc.shared" >> ~/.bashrc

if [[ ! -d ~/.oh-my-zsh/ ]]; then
  # Install Oh-my-zsh
  chmod o-w,g-w /usr/local/share/zsh /usr/local/share/zsh/site-functions
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
  echo "source ~/.zshrc.shared" > ~/.zshrc
fi

set +e
install_zsh_plugin 'romkatv/powerlevel10k' 'themes/powerlevel10k'
install_zsh_plugin 'fdw/ranger-autojump' 'plugins/ranger-autojump'
install_zsh_plugin 'zsh-users/zsh-autosuggestions' 'plugins/zsh-autosuggestions'
install_zsh_plugin 'zsh-users/zsh-syntax-highlighting' 'plugins/zsh-syntax-highlighting'
install_zsh_plugin 'MichaelAquilina/zsh-you-should-use' 'plugins/you-should-use'
install_zsh_plugin 'jeffreytse/zsh-vi-mode' 'plugins/zsh-vi-mode'
set -e
