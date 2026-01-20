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
asdf:
  opt_out: true  # Required to use mise instead
clickhouse:
  bin: "/opt/homebrew/bin/clickhouse"
  enabled: true
  max_memory_usage: 8589934592
  max_server_memory_usage: 16589934592
gdk:
  experimental:
    ruby_services: true
  overwrite_changes: true
  update_hooks:
    before:
      - support/exec-cd gitlab bin/spring stop || true
    after:
      - git -C "${GDK_ROOT}/gitlab" restore db/structure.sql
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
hostname: gdk.test
listen_address: 172.16.123.1
mise:
  enabled: true
port: 3000
postgresql:
  host: localhost
registry:
  auth_enabled: true
  enabled: false
  host: registry.test
  listen_address: 0.0.0.0
  self_signed: true
runner:
  bin: "${HOME}/Developer/gitlab.com/gitlab-org/gitlab-runner/out/binaries/gitlab-runner"
  config_file: "${HOME}/.gitlab-runner/config.gdk.toml"
  enabled: false
snowplow_micro:
  enabled: false
  port: 9090
telemetry:
  enabled: true
  username: 526355293c854a36885c7a8d6b61a336
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

  (cd ${GDK_ROOT} && mise x -- lefthook install)
fi

git -C ${GDK_ROOT}/gitlab config --unset-all remote.origin.fetch
git -C ${GDK_ROOT}/gitlab config --add remote.origin.fetch '+refs/heads/master:refs/remotes/origin/master'
git -C ${GDK_ROOT}/gitlab config --add remote.origin.fetch '+refs/heads/pedropombeiro/*:refs/remotes/origin/pedropombeiro/*'

# Populate opencode configuration
if [[ -n ${GDK_ROOT} ]]; then
  mkdir -p "${GDK_ROOT}/gitlab/.opencode"
  cat << 'EOF' > "${GDK_ROOT}/gitlab/.opencode/opencode.json"
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [".gitlab/duo/chat-rules.md"]
}
EOF

cat << 'EOF' > "${GDK_ROOT}/gitlab/.mise.local.toml"
[env]
OPENCODE_CONFIG="{{env.GDK_ROOT}}/gitlab/.opencode/opencode.json"
_.path = { value = ["{{env.GDK_ROOT}}/gitlab/bin"], after = true }
EOF
fi

${YADM_SCRIPTS}/run-checks.zsh
