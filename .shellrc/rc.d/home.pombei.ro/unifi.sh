#!/usr/bin/env bash

function loggatewayjson() {
  ssh gateway "tail -f -n 100 /var/log/messages" | \
    rg "kernel:" | \
    sed "s/]IN/] IN/" | \
    jq --unbuffered -R '. | rtrimstr(" ") | split(": ") | {date: (.[0] | split(" ") | .[0:4] | join(" "))} + (.[1] | capture("\\[.+\\] \\[(?<rule>.*)\\].*")) + ((.[1] | capture("\\[.+\\] (?<rest>.*)") | .rest | split(" ") | map(select(startswith("[") == false) | split("=") | {(.[0]): .[1]})) | (reduce .[] as $item ({}; . + $item)))'
}

function loggateway() {
  if command -v lnav >/dev/null; then
    ssh -fn gateway 'tail -fqn 100000 /var/log/messages' 2>/dev/null | lnav
  else
    loggatewayjson | jq --unbuffered -r '"\(.date) - \(.rule)\tIN=\(.IN)  \t\(.PROTO)\tSRC=\(.SRC)@\(.SPT)\tDST=\(.DST)@\(.DPT)\tLEN=\(.LEN)\t"'
  fi
}

alias logap='ssh ap "tcpdump -np | sed \"s|, options \[.*\]||\""'
