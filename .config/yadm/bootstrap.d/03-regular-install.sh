#!/bin/sh

system_type="$(uname -s)"

if [ "${system_type}" = "Linux" ]; then

  $HOME/.install/linux/install.sh

fi
