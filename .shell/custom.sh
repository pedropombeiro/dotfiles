[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
[ -f /usr/local/etc/profile.d/autojump.sh ] && source /usr/local/etc/profile.d/autojump.sh

if [ -e $HOME/.nix-profile/etc/profile.d/nix.sh ]; then
  [[ "$OSTYPE" == "darwin"* ]] && export NIX_IGNORE_SYMLINK_STORE=1
  . $HOME/.nix-profile/etc/profile.d/nix.sh
fi

if [ command -v rbenv >/dev/null 2>&1 ]; then
  export PATH="$HOME/.rbenv/bin:$PATH"
  eval "$(rbenv init -)"
fi

if [ -d "$HOME/.nvm" ]; then
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
fi

[ -d "/usr/local/bin/orka" ] && export PATH="$PATH:/usr/local/bin/orka"
