#!/usr/bin/env bash

if command -v go >/dev/null; then
  if [ -z "$GOPATH" ]; then
    GOPATH="${HOME}/go"
    GOCACHE="${GOPATH}/.cache/go-build"

    export GOCACHE
    export GOPATH
  fi
fi
