# Skip all this for non-interactive shells
[[ -z "$PS1" ]] && return

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# load custom executable functions
if [ -f '$HOME/.shellrc/zshrc.d/functions/*' ]; then
  for function in $HOME/.shellrc/zshrc.d/functions/*; do
    source $function
  done
fi

# extra files in $HOME/.shellrc/zshrc.d/configs/pre, $HOME/.shellrc/zshrc.d/configs, and $HOME/.shellrc/zshrc.d/configs/post
# these are loaded first, second, and third, respectively.
_load_settings() {
  _dir="$1"
  if [ -d "$_dir" ]; then
    if [ -d "$_dir/pre" ]; then
      for config in "$_dir"/pre/**/*~*.zwc(N-.); do
        . $config
      done
    fi

    for config in "$_dir"/**/*(N-.); do
      case "$config" in
        "$_dir"/(pre|post)/*|*.zwc)
          :
          ;;
        *)
          . $config
          ;;
      esac
    done

    if [ -d "$_dir/post" ]; then
      for config in "$_dir"/post/**/*~*.zwc(N-.); do
        . $config
      done
    fi
  fi
}
_load_settings "$HOME/.shellrc/zshrc.d/configs"

# Local config
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# Load all files from .shell/rc.d directory
if [ -d $HOME/.shellrc/rc.d ]; then
  for file in $HOME/.shellrc/rc.d/*.sh; do
    source $file
  done
fi

# aliases
[[ -f ~/.aliases.sh ]] && source ~/.aliases.sh

[ -f "$ZSH/oh-my-zsh.sh" ] && source $ZSH/oh-my-zsh.sh
