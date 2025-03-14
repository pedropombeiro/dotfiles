#!/usr/bin/env zsh

YADM_SCRIPTS=$( cd -- "$( dirname -- ${(%):-%x} )/../scripts" &> /dev/null && pwd )

source "${YADM_SCRIPTS}/colors.sh"

# Create mise shims for RubyMine debugger
mise reshim

# Populate gdk.yml
if [[ -n ${GDK_ROOT} ]]; then
  # From https://gitlab.com/gitlab-org/gitlab-development-kit/-/blob/main/doc/howto/registry.md#set-up-pushing-and-pulling-of-images-over-http
  cat << EOF > ${GDK_ROOT}/gdk.tmp.yml
---
hostname: gdk.test
listen_address: 172.16.123.1
port: 3000
asdf:
  opt_out: true  # Required to use mise instead
mise:
  enabled: true
clickhouse:
  bin: "/opt/homebrew/bin/clickhouse"
  enabled: true
  max_memory_usage: 8589934592
  max_server_memory_usage: 16589934592
gdk:
  experimental:
    ruby_services: true
  update_hooks:
    before:
      - support/exec-cd gitlab bin/spring stop || true
    after:
      - git -C "${GDK_ROOT}/gitlab" restore db/structure.sql
  overwrite_changes: true
# https:
#   enabled: true
# nginx:
#   enabled: true
#   ssl:
#     certificate: "${GDK_ROOT}/gdk.localhost+2.pem"
#     key: "${GDK_ROOT}/gdk.localhost+2-key.pem"
gitlab:
  rails:
#     address: 'http://gdk.test:3000'
#     sherlock: true
postgresql:
  host: localhost
registry:
  enabled: false
  host: registry.test
  self_signed: true
  auth_enabled: true
  listen_address: 0.0.0.0
runner:
  bin: "${HOME}/Developer/gitlab.com/gitlab-org/gitlab-runner/out/binaries/gitlab-runner"
  config_file: "${HOME}/.gitlab-runner/config.gdk.toml"
  enabled: false
snowplow_micro:
  enabled: false
  port: 9090
trusted_directories:
  - "${GDK_ROOT}"
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

# Populate lefthook-local.yml
if [[ -n ${GDK_ROOT} ]]; then
  cat << EOF > ${GDK_ROOT}/lefthook-local.yml
EOF

  (cd ${GDK_ROOT} && lefthook install)
fi

${YADM_SCRIPTS}/run-checks.zsh
