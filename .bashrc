# .bashrc
if [[ $- != *i* ]] ; then
  # shell is non-interactive. be done now!
  return
fi

# Load all files from .shell/bashrc.d directory
if [ -d $HOME/.shellrc/bashrc.d ]; then
  for file in $HOME/.shellrc/bashrc.d/*.bash; do
    source $file
  done
fi

# Load all files from .shell/rc.d directory
if [ -d $HOME/.shellrc/rc.d ]; then
  for file in $HOME/.shellrc/rc.d/*.sh; do
    source $file
  done
fi

# Load local files
test -f ~/.bashrc.local && source ~/.bashrc.local
