#!/usr/bin/env zsh

YADM_SCRIPTS=$( cd -- "$( dirname -- ${(%):-%x} )/../scripts" &> /dev/null && pwd )

source "${YADM_SCRIPTS}/colors.sh"

# Create mise shims for key-value-server plist and for RubyMine debugger
mise reshim

printf "${YELLOW}%s${NC}\n" "Pruning mise..."
(cd ${GDK_ROOT}/gitlab && mise prune)

# Populate gdk.yml
if [[ -n ${GDK_ROOT} ]]; then
  cat << EOF > ${GDK_ROOT}/gdk.tmp.yml
---
hostname: gdk.test
port: 3000
runner:
  bin: "${HOME}/Developer/gitlab.com/gitlab-org/gitlab-runner/out/binaries/gitlab-runner"
  config_file: "${HOME}/.gitlab-runner/config.gdk.toml"
  enabled: false
snowplow_micro:
  enabled: false
  port: 9090
asdf:
  opt_out: true  # Required to use mise instead
gdk:
  update_hooks:
    before:
      - cd gitlab && scalar register  # Improve performance for rebasing/status/etc.
    after:
      - git -C gitlab restore db/structure.sql
  overwrite_changes: true
# https:
#   enabled: true
# nginx:
#   enabled: true
#   ssl:
#     certificate: "${GDK_ROOT}/gdk.localhost+2.pem"
#     key: "${GDK_ROOT}/gdk.localhost+2-key.pem"
trusted_directories:
  - "${GDK_ROOT}"
listen_address: 0.0.0.0
# gitlab:
#   rails:
#     sherlock: true
vite:
  enabled: true
webpack:
  enabled: false
EOF
fi

if ! delta "${GDK_ROOT}/gdk.yml" "${GDK_ROOT}/gdk.tmp.yml"; then
  printf "${YELLOW}%s${NC}\n" "Overwriting gdk.yml. Please rerun 'gdk reconfigure'..."
  cp -f "${GDK_ROOT}/gdk.yml" "${GDK_ROOT}/gdk.prev.yml"
  cp -f "${GDK_ROOT}/gdk.tmp.yml" "${GDK_ROOT}/gdk.yml"
fi
rm -f "${GDK_ROOT}/gdk.tmp.yml"

scalar reconfigure -a

# Populate lefthook-local.yml
if [[ -n ${GDK_ROOT} ]]; then
  cat << EOF > ${GDK_ROOT}/lefthook-local.yml
# For git pulls
post-merge:
  follow: true
  commands:
    mise-install:
      run: mise install

# When switching branches
post-checkout:
  follow: true
  commands:
    mise-install:
      run: mise install
EOF

  (cd ${GDK_ROOT} && lefthook install)
fi

function print_op() {
  printf "${CYAN}%s${NC}\n" "- $1"
}

function print_op_stay() {
  printf "${CYAN}%-55s${NC} " "- $1..."
}

function print_ok() {
  printf "${GREEN}%s${NC}\n" '✅ OK'
}

function print_failure() {
  printf "${RED}%s${NC}\n" "$1"
}

any_failed=0

print_op_stay "Checking key-value-server (for Desk controller)"
if pgrep key-value-server >/dev/null; then
  print_ok
else
  echo
  print_failure "key-value-server is not running"
  any_failed=1

  print_op_stay "Checking if key-value-server is in PATH"
  if which key-value-server >/dev/null; then
    print_ok
  else
    print_failure "key-value-server is not in PATH. Ensure that a working cargo version is installed, run `cargo install --git https://github.com/pedropombeiro/key-value-server` and then `mise reshim`"
  fi
fi

print_op_stay "Checking nginx (for Desk Controller)"
if pgrep nginx >/dev/null; then
  print_ok
else
  echo
  print_failure "nginx is not running"
  any_failed=1
fi

print_op_stay "Checking if key-value-server is available through nginx"
if curl -s http://localhost:18087/deskcontroller/desk-position; then
  print_ok
else
  any_failed=1
fi

if [[ $any_failed -eq 1 ]]; then
  printf "${YELLOW}%s${NC}\n" "⚠️  Checks finished with errors/warnings!"
  (exit 1)
else
  printf "${GREEN}%s${NC}\n" "✅ Checks finished!"
fi
