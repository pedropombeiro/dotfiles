#!/usr/bin/env bash

function loggatewayjson() {
  ssh gateway "tail -f /var/log/messages" | \
    rg "kernel:" | \
    sed "s/]IN/] IN/" | \
    jq -R '. | rtrimstr(" ") | split(": ") | {date: .[0] | rtrimstr(" UniFiSecurityGateway3P kernel")} + (.[1] | capture("\\[(?<rule>.*)\\].*")) + ((.[1] | split(" ") | map(select(startswith("[") == false) | split("=") | {(.[0]): .[1]})) | (reduce .[] as $item ({}; . + $item)))'
}

function loggateway() {
  loggatewayjson | jq -r '"\(.date) - \(.rule)\tIN=\(.IN) \t\(.PROTO)\tSRC=\(.SRC)@\(.SPT)\tDST=\(.DST)@\(.DPT)\tLEN=\(.LEN)\t"'
}

alias logap='ssh ap "tcpdump -np | sed \"s|, options \[.*\]||\""'
