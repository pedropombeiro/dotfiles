#!/usr/bin/env bash

if [ -f /usr/local/opt/asdf/asdf.sh ]; then
  # . $(brew --prefix asdf)/asdf.sh is more generic, but very, very slow
  . /usr/local/opt/asdf/asdf.sh
fi
