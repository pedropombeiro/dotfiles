#!/usr/bin/env sh

if [ -z "$(yadm config local.class)" ]; then
  echo "Enter machine class (Personal or Work):"
  read -r CLASS
  yadm config local.class "${CLASS}"
fi
