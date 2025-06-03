#!/usr/bin/env bash

# Enable TouchID on shell (https://apple.stackexchange.com/questions/259093/can-touch-id-on-mac-authenticate-sudo-in-terminal)
sed "s/^#auth/auth/" /etc/pam.d/sudo_local.template | \
  sudo tee /etc/pam.d/sudo_local
