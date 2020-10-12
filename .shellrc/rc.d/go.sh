#!/usr/bin/env bash

if command -v asdf >/dev/null && asdf current golang >/dev/null; then
  export GOPATH="${HOME}/go"
  export GOROOT="$(asdf where golang)/go"
fi
