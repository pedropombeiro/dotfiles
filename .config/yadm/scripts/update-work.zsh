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

populate_gdk_yaml() {
  local gdk_root
  local clickhouse_bin_path

  gdk_root=${1}
  clickhouse_bin_path=${2}

  cat << EOF > ${gdk_root}/gdk.tmp.yml
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
      - git -C "${gdk_root}/gitlab" restore db/structure.sql
# https:
#   enabled: true
# nginx:
#   enabled: true
#   ssl:
#     certificate: "${gdk_root}/gdk.localhost+2.pem"
#     key: "${gdk_root}/gdk.localhost+2-key.pem"
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
  - "${gdk_root}"
vite:
  enabled: true
webpack:
  enabled: false
EOF

  if ! delta "${gdk_root}/gdk.yml" "${gdk_root}/gdk.tmp.yml"; then
    printf "${YELLOW}%s${NC}\n" "Overwriting gdk.yml. Please rerun 'gdk reconfigure'..."
    cp -f "${gdk_root}/gdk.yml" "${gdk_root}/gdk.prev.yml"
    cp -f "${gdk_root}/gdk.tmp.yml" "${gdk_root}/gdk.yml"
  fi
  rm -f "${gdk_root}/gdk.tmp.yml"
}

setup_lefthook() {
  local gdk_root

  gdk_root=${1}

  cat << EOF > ${gdk_root}/lefthook-local.yml
EOF

  (cd ${gdk_root} && mise x -- lefthook install)
}

cleanup_gitlab_excludes() {
  local gdk_root
  local gitlab_exclude_file

  gdk_root=${1}
  gitlab_exclude_file="${gdk_root}/gitlab/.git/info/exclude"

  rm -f "${gdk_root}/gitlab/opencode.jsonc"
  if [[ -f ${gitlab_exclude_file} ]]; then
    sed -i '' '/^opencode\.jsonc$/d' "${gitlab_exclude_file}"
  fi
}

write_mise_root_config() {
  local gdk_root

  gdk_root=${1}

  cat << EOF > "${gdk_root}/.mise.toml"
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
}

write_mise_gitlab_config() {
  local gdk_root

  gdk_root=${1}

  cat << EOF > "${gdk_root}/gitlab/.mise.toml"
## NOTE: Do not edit directly - Auto generated from ${0:A}
[env]
EOF
}

sync_dotfiles_ai_file() {
  local gdk_root
  local dotfiles_ai_dir
  local dotfiles_ai_file
  local gdk_ai_file

  gdk_root=${1}
  dotfiles_ai_dir="${HOME}/.config/dotfiles/gitlab/.ai"
  dotfiles_ai_file="${dotfiles_ai_dir}/lessons-learned.local.md"
  gdk_ai_file="${gdk_root}/gitlab/.ai/lessons-learned.local.md"

  mkdir -p "${dotfiles_ai_dir}"

  if [[ -f "${gdk_ai_file}" && ! -L "${gdk_ai_file}" ]]; then
    cp -a "${gdk_ai_file}" "${dotfiles_ai_file}"
  fi

  if [[ -L "${gdk_ai_file}" ]]; then
    local current_ai_target
    current_ai_target=$(readlink "${gdk_ai_file}")
    if [[ "${current_ai_target}" != "${dotfiles_ai_file}" ]]; then
      rm -f "${gdk_ai_file}"
    fi
  elif [[ -e "${gdk_ai_file}" ]]; then
    rm -f "${gdk_ai_file}"
  fi

  if [[ ! -L "${gdk_ai_file}" ]]; then
    ln -s "${dotfiles_ai_file}" "${gdk_ai_file}"
  fi
}

write_opencode_config() {
  local gdk_root

  gdk_root=${1}

  sync_dotfiles_ai_file "${gdk_root}"
  rm -f "${gdk_root}/gitlab/opencode.json" && echo "Removed opencode.json file"
  cat << EOF > "${gdk_root}/gitlab/opencode.jsonc"
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
  populate_gdk_yaml "${GDK_ROOT}" "${clickhouse_bin_path}"

  # Populate lefthook-local.yml
  setup_lefthook "${GDK_ROOT}"

  # Clean up stale files from old configuration
  cleanup_gitlab_excludes "${GDK_ROOT}"

  # Populate .mise.toml (GDK root level) - tokens go in .mise.local.toml
  write_mise_root_config "${GDK_ROOT}"

  # Populate .mise.toml (gitlab repo level) - tokens go in .mise.local.toml
  write_mise_gitlab_config "${GDK_ROOT}"

  # Populate opencode configuration
  write_opencode_config "${GDK_ROOT}"

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
