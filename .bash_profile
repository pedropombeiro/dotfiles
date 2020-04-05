# .bash_profile

if [ -f $HOME/.bashrc ]; then
  source $HOME/.bashrc
fi

# Load all files from .shell/login.d directory
if [ -d $HOME/.shellrc/login.d ]; then
  for file in $HOME/.shellrc/login.d/*.sh; do
    source $file
  done
fi

# Load local files
test -f ~/.bash_profile.local && source ~/.bash_profile.local
