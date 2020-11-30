#!/usr/bin/env bash

if command -v asdf >/dev/null && asdf current golang >/dev/null; then
  export GOPATH="${HOME}/go"

  export PATH="${PATH}:${GOPATH}/bin"

  plugins+=(golang)
fi
