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

#alias loggateway='ssh gateway "tail -f /var/log/messages | sed -E \"s/( UniFiSecurityGateway3P kernel|-default| TOS=0x[0-9A-F]+| PREC=0x[0-9A-F]+| MAC=[0-9a-f:]*)//gm;t;d\"" | grep -E "\w[A-Z]+="'
alias logap='ssh ap "tcpdump -np | sed \"s|, options \[.*\]||\""'
