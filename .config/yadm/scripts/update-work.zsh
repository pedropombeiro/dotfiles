#!/usr/bin/env zsh

YADM_SCRIPTS=$( cd -- "$( dirname -- ${(%):-%x} )/../scripts" &> /dev/null && pwd )

source "${YADM_SCRIPTS}/colors.sh"

ensure_clickhouse_binary() {
  local clickhouse_bin

  clickhouse_bin=${1}
  [[ -n ${clickhouse_bin} && -x ${clickhouse_bin} ]] || return 0

  if xattr -p com.apple.quarantine ${clickhouse_bin} >/dev/null 2>&1; then
    printf "${YELLOW}%s${NC}\n" 'ClickHouse is quarantined, clearing macOS quarantine...'
    xattr -d com.apple.quarantine ${clickhouse_bin} >/dev/null 2>&1 ||
      printf "${YELLOW}%s${NC}\n" 'Failed to clear ClickHouse quarantine; migrations may fail.'
  fi
}

# Create mise shims for RubyMine debugger
mise reshim

if [[ -n ${GDK_ROOT} ]]; then
  local clickhouse_bin_path

  clickhouse_bin_path=$(mise which clickhouse 2>/dev/null || true)
  [[ -n ${clickhouse_bin_path} ]] || clickhouse_bin_path=/opt/homebrew/bin/clickhouse

  ensure_clickhouse_binary ${clickhouse_bin_path}

  # Populate gdk.yml
  # From https://gitlab.com/gitlab-org/gitlab-development-kit/-/blob/main/doc/howto/registry.md#set-up-pushing-and-pulling-of-images-over-http
  cat << EOF > ${GDK_ROOT}/gdk.tmp.yml
---
asdf:
  opt_out: true  # Required to use mise instead
clickhouse:
  bin: "${clickhouse_bin_path}"
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
redis:
  backend: valkey
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

  if ! delta "${GDK_ROOT}/gdk.yml" "${GDK_ROOT}/gdk.tmp.yml"; then
    printf "${YELLOW}%s${NC}\n" "Overwriting gdk.yml. Please rerun 'gdk reconfigure'..."
    cp -f "${GDK_ROOT}/gdk.yml" "${GDK_ROOT}/gdk.prev.yml"
    cp -f "${GDK_ROOT}/gdk.tmp.yml" "${GDK_ROOT}/gdk.yml"
  fi
  rm -f "${GDK_ROOT}/gdk.tmp.yml"

  # Populate lefthook-local.yml
  cat << EOF > ${GDK_ROOT}/lefthook-local.yml
EOF

  (cd ${GDK_ROOT} && mise x -- lefthook install)

  # Clean up stale files from old configuration
  rm -f "${GDK_ROOT}/gitlab/opencode.jsonc"
  local gitlab_exclude_file="${GDK_ROOT}/gitlab/.git/info/exclude"
  if [[ -f ${gitlab_exclude_file} ]]; then
    sed -i '' '/^opencode\.jsonc$/d' "${gitlab_exclude_file}"
  fi

  # Populate .mise.toml (GDK root level) - tokens go in .mise.local.toml
  cat << EOF > "${GDK_ROOT}/.mise.toml"
## NOTE: Do not edit directly - Auto generated from ${0:A}
[env]
BUNDLER_CHECKSUM_VERIFICATION_OPT_IN = "1"
COREPACK_ENABLE_AUTO_PIN = "0"
ENABLE_FDOC = "1"
ENABLE_SPRING = "1"
GITLAB_USE_MODEL_LOAD_BALANCING = "1"
GITLAB_VIM_URL = "https://gitlab.com"
OP_BIOMETRIC_UNLOCK_ENABLED = "true"
OPENCODE_MODEL = "gitlab/duo-chat-opus-4-6"
PUMA_WORKER_TIMEOUT = "9999999"
QA_GITLAB_URL = "http://gdk.test:3000"
QA_LOG_LEVEL = "DEBUG"
RAILS_HOSTS = "127.0.0.1,localhost,host.docker.internal,gdk.test,gdk.localhost"
SHARP_IGNORE_GLOBAL_LIBVIPS = 1 # Avoid conflict with libvips from Homebrew (installed by ueberzugpp) in gitlab-http-router
TELEPORT_USE_LOCAL_SSH_AGENT = "false"
WRANGLER_LOG_PATH = "{{env.HOME}}/gitlab-development-kit/log/wrangler"
_.path = ["{{env.HOME}}/Developer/gitlab.com/gitlab-org/gitlab-runner/out/binaries"]
EOF

  # Populate .mise.toml (gitlab repo level) - tokens go in .mise.local.toml
  cat << EOF > "${GDK_ROOT}/gitlab/.mise.toml"
## NOTE: Do not edit directly - Auto generated from ${0:A}
[env]
EOF

  # Populate opencode configuration
  rm -f "${GDK_ROOT}/gitlab/opencode.json" && echo "Removed opencode.json file"
  cat << EOF > "${GDK_ROOT}/gitlab/opencode.jsonc"
// NOTE: Do not edit directly - Auto generated from ${0:A}
{
  "\$schema": "https://opencode.ai/config.json",
  "instructions": [
    "AGENTS.local.md",
    ".ai/AGENTS.md",
    ".ai/lessons-learned.local.md",
    ".gitlab/duo/chat-rules.md"
  ],
  "mcp": {
    "knowledge-graph": {
      "type": "remote",
      "url": "http://localhost:27495/mcp/sse",
      "enabled": true
    }
  },
  // Disable formatter to preserve project's existing code style
  "formatter": {
    "standardrb": {
      "disabled": true
    }
  },
  "provider": {
    "gitlab": {
      "options": {
        "instanceUrl": "https://gitlab.com",
        "featureFlags": {
          "duo_agent_platform_agentic_chat": true,
          "duo_agent_platform": true
        }
      }
    }
  }
}
EOF

  mise trust "${GDK_ROOT}"

  # Add .mise.local.toml to local git exclude if not already present
  local exclude_file="${GDK_ROOT}/.git/info/exclude"
  if [[ -f ${exclude_file} ]] && ! grep -q '^\.mise\.local\.toml$' "${exclude_file}"; then
    echo '.mise.local.toml' >> "${exclude_file}"
  fi

  git -C ${GDK_ROOT}/gitlab config --unset-all remote.origin.fetch
  git -C ${GDK_ROOT}/gitlab config --add remote.origin.fetch '+refs/heads/master:refs/remotes/origin/master'
  git -C ${GDK_ROOT}/gitlab config --add remote.origin.fetch '+refs/heads/pedropombeiro/*:refs/remotes/origin/pedropombeiro/*'
fi

${YADM_SCRIPTS}/run-checks.zsh
