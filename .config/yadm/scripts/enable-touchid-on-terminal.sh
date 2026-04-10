#!/usr/bin/env bash

# Enable TouchID for sudo in terminal (including tmux sessions)
# https://apple.stackexchange.com/questions/259093/can-touch-id-on-mac-authenticate-sudo-in-terminal
PAM_REATTACH="/opt/homebrew/lib/pam/pam_reattach.so"

{
  echo "# sudo_local: local config file which survives system update and is included for sudo"
  [[ -f "$PAM_REATTACH" ]] && echo "auth       optional       $PAM_REATTACH"
  echo "auth       sufficient     pam_tid.so"
} | sudo tee /etc/pam.d/sudo_local
