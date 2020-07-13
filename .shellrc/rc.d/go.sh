#!/usr/bin/env bash

export GOPATH=~/go
PATH="$(command -v go)/..:${GOPATH}/bin:${PATH}"
export PATH
