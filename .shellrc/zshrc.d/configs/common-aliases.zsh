#!/usr/bin/env zsh

plugins+=(common-aliases)

function t() {
  tail -f $1 | bat --paging=never -l log --style='numbers'
}
