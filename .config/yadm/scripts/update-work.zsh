#!/usr/bin/env zsh

YADM_SCRIPTS=$( cd -- "$( dirname -- ${(%):-%x} )/../scripts" &> /dev/null && pwd )

source "${YADM_SCRIPTS}/colors.sh"
(( $+functions[_update_step] )) || _update_step() { : }

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

  cat << 'EOF' > ${gdk_root}/gitlab/lefthook-local.yml
pre-push:
  commands:
    danger:
      env:
        LANG: en_US.UTF-8
        RUBYOPT: "-EUTF-8"
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

sync_dotfiles_to_gitlab() {
  local gdk_root dotfiles_dir gitlab_dir exclude_file
  local dotfiles_file rel_path gdk_file current_target

  gdk_root=${1}
  dotfiles_dir="${HOME}/.config/dotfiles/gitlab"
  gitlab_dir="${gdk_root}/gitlab"
  exclude_file="${gitlab_dir}/.git/info/exclude"

  [[ -d "${dotfiles_dir}" ]] || return 0

  fd -tf . "${dotfiles_dir}" | while read -r dotfiles_file; do
    rel_path="${dotfiles_file#${dotfiles_dir}/}"
    gdk_file="${gitlab_dir}/${rel_path}"

    mkdir -p "${gdk_file:h}"

    if [[ -f "${gdk_file}" && ! -L "${gdk_file}" ]]; then
      cp -a "${gdk_file}" "${dotfiles_file}"
    fi

    if [[ -L "${gdk_file}" ]]; then
      current_target=$(readlink "${gdk_file}")
      if [[ "${current_target}" != "${dotfiles_file}" ]]; then
        rm -f "${gdk_file}"
      fi
    elif [[ -e "${gdk_file}" ]]; then
      rm -f "${gdk_file}"
    fi

    if [[ ! -L "${gdk_file}" ]]; then
      ln -s "${dotfiles_file}" "${gdk_file}"
    fi

    if [[ -f "${exclude_file}" ]] && ! grep -qF "/${rel_path}" "${exclude_file}"; then
      echo "/${rel_path}" >> "${exclude_file}"
    fi
  done
}

ensure_spring_binstubs_skip_worktree() {
  local gdk_root gitlab_dir

  gdk_root=${1}
  gitlab_dir="${gdk_root}/gitlab"

  [[ -d "${gitlab_dir}" ]] || return 0

  source "${HOME}/.shellrc/zshrc.d/functions/scripts/spring-binstubs.zsh"
  spring_binstubs ensure "${gitlab_dir}"
}

write_opencode_config() {
  local gdk_root

  gdk_root=${1}

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

write_wakatime_project() {
  local git_dir remote_url project_name

  git_dir=${1}
  [[ "$(git -C "${git_dir}" rev-parse --show-toplevel 2>/dev/null)" == "${git_dir}" ]] || return 0

  remote_url=$(git -C "${git_dir}" remote get-url origin 2>/dev/null) || { rm -f "${git_dir}/.wakatime-project"; return 0; }
  project_name=${remote_url#*gitlab.com/}
  project_name=${project_name#*gitlab.com:}
  project_name=${project_name%.git}
  project_name=${project_name##*/}

  [[ -n "${project_name}" ]] || return 0

  echo "${project_name}" > "${git_dir}/.wakatime-project"

  local exclude_file="${git_dir}/.git/info/exclude"
  if [[ -f "${exclude_file}" ]] && ! grep -q '^\.wakatime-project$' "${exclude_file}"; then
    echo '.wakatime-project' >> "${exclude_file}"
  fi
}

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

  # Symlink personal dotfiles into gitlab repo
  sync_dotfiles_to_gitlab "${GDK_ROOT}"

  # Ensure spring binstubs are hidden from status by default
  ensure_spring_binstubs_skip_worktree "${GDK_ROOT}"

  # Populate opencode configuration
  write_opencode_config "${GDK_ROOT}"

  # Populate wakatime project files for GDK root and all subprojects
  write_wakatime_project "${GDK_ROOT}"
  for subdir in "${GDK_ROOT}"/*/; do
    write_wakatime_project "${subdir%/}"
  done

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

_update_step "run checks"
${YADM_SCRIPTS}/run-checks.zsh
