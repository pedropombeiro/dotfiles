#!/usr/bin/env bash

alias loggateway='ssh gateway "tail -f /var/log/messages | sed -E \"s/( UniFiSecurityGateway3P kernel|-default| TOS=0x[0-9A-F]+| PREC=0x[0-9A-F]+| MAC=[0-9a-f:]*)//gm;t;d\"" | grep -E "\w[A-Z]+="'
alias logap='ssh ap "tcpdump -np | sed \"s|, options \[.*\]||\""'
