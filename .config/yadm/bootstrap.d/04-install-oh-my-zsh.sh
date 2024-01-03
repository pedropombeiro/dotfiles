#!/usr/bin/env bash

YADM_SCRIPTS=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../scripts" &>/dev/null && pwd)

source "${YADM_SCRIPTS}/colors.sh"

function install_zsh_plugin() {
  local repo="$1"
  local path="$2"
  local dest_path="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/${path}"
  if [[ ! -d "${dest_path}" ]]; then
    printf "${YELLOW}%s${NC}\n" "Cloning ${repo} ..."
    git clone --depth=1 https://github.com/"${repo}".git "${dest_path}"
  fi
}

type -f mise >/dev/null 2>&1 || eval "$(mise activate bash)"

grep '.bash_profile.shared' "${HOME}/.bash_profile" >/dev/null 2>&1 || echo "source ~/.bash_profile.shared" >>"${HOME}/.bash_profile"
grep '.bashrc.shared' "${HOME}/.bashrc" >/dev/null 2>&1 || echo "source ~/.bashrc.shared" >>"${HOME}/.bashrc"

if [[ ! -d "${HOME}/.oh-my-zsh/" ]]; then
  # Install Oh-my-zsh
  printf "${YELLOW}%s${NC}\n" "Installing Oh-my-zsh..."
  if [[ $(uname -r) =~ qnap ]]; then
    CHSH=no RUNZSH=no KEEP_ZSHRC=yes ZSH=/share/homes/${USER}/.oh-my-zsh sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    chmod o-w,g-w /usr/local/share/zsh /usr/local/share/zsh/site-functions
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
  fi
  echo "source ~/.zshrc.shared" >"${HOME}/.zshrc"
fi

set +e
install_zsh_plugin 'romkatv/powerlevel10k' 'themes/powerlevel10k'
install_zsh_plugin 'zsh-users/zsh-autosuggestions' 'plugins/zsh-autosuggestions'
install_zsh_plugin 'zsh-users/zsh-syntax-highlighting' 'plugins/zsh-syntax-highlighting'
install_zsh_plugin 'MichaelAquilina/zsh-you-should-use' 'plugins/you-should-use'
install_zsh_plugin 'jeffreytse/zsh-vi-mode' 'plugins/zsh-vi-mode'
set -e
