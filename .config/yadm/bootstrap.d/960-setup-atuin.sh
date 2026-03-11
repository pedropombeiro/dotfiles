#!/usr/bin/env bash

YADM_SCRIPTS=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../scripts" &>/dev/null && pwd)

# shellcheck source=../scripts/colors.sh
source "${YADM_SCRIPTS}/colors.sh"

if ! command -v atuin &>/dev/null; then
  printf "${YELLOW}%s${NC}\n" "atuin not found, skipping sync setup"
  exit 0
fi

# Already logged in — nothing to do
if atuin status 2>/dev/null | grep -q 'Username:'; then
  printf "${GREEN}%s${NC}\n" "atuin sync already configured"
  exit 0
fi

printf "${YELLOW}%s${NC}\n" "Setting up atuin sync..."
printf "%s\n" "Do you want to set up atuin sync? (r)egister new account, (l)ogin existing, (s)kip"
read -r -p "> " choice

case "${choice}" in
  r|R)
    read -r -p "Username: " username
    read -r -p "Email: " email
    atuin register -u "${username}" -e "${email}"
    printf "${GREEN}%s${NC}\n" "Registered! Save your encryption key — you need it to login on other machines."
    printf "${CYAN}%s${NC}\n" "Run 'atuin key' to display it."
    atuin sync
    ;;
  l|L)
    read -r -p "Username: " username
    read -r -s -p "Key (encryption key from 'atuin key'): " key
    echo
    atuin login -u "${username}" -k "${key}"
    atuin sync
    ;;
  *)
    printf "${YELLOW}%s${NC}\n" "Skipping atuin sync setup"
    ;;
esac
