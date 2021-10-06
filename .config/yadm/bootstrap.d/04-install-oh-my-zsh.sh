#!/usr/bin/env bash

grep '.bash_profile.shared' ~/.bash_profile >/dev/null 2>&1|| echo "source ~/.bash_profile.shared" >> ~/.bash_profile
grep '.bashrc.shared' ~/.bashrc >/dev/null 2>&1 || echo "source ~/.bashrc.shared" >> ~/.bashrc

if [[ ! -d ~/.oh-my-zsh/ ]]; then
  # Install Oh-my-zsh
  chmod o-w,g-w /usr/local/share/zsh /usr/local/share/zsh/site-functions
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
  echo "source ~/.zshrc.shared" > ~/.zshrc
fi

set +e
[[ -d "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/themes/powerlevel10k" ]] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/themes/powerlevel10k"
[[ -d "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]] || git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
[[ -d "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]] || git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
[[ -d "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/you-should-use" ]] || git clone https://github.com/MichaelAquilina/zsh-you-should-use.git "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/you-should-use"
set -e
