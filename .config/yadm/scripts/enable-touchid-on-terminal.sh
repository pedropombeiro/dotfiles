#!/usr/bin/env bash

# Enable TouchID on shell
grep 'pam_tid.so' /etc/pam.d/sudo >/dev/null ||
  echo -e "auth       sufficient     pam_tid.so\n$(cat /etc/pam.d/sudo)" |
  sudo tee /etc/pam.d/sudo
