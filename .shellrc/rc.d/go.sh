#!/usr/bin/env bash

if command -v asdf >/dev/null && asdf current golang >/dev/null; then
  GOPATH="${HOME}/go"
  GOCACHE="${GOPATH}/.cache/go-build"
  PATH="${PATH}:${GOPATH}/bin"

  export GOCACHE
  export GOPATH
  export PATH
fi
