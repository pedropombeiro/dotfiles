#!/usr/bin/env bash

# Disable check for active go environment to speed up shell load time
#if command -v asdf >/dev/null && asdf current golang >/dev/null; then
if command -v go >/dev/null; then
  GOPATH="${HOME}/go"
  GOCACHE="${GOPATH}/.cache/go-build"
  PATH="${PATH}:${GOPATH}/bin"

  export GOCACHE
  export GOPATH
  export PATH
fi
