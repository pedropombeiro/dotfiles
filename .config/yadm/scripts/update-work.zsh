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

${YADM_SCRIPTS}/run-checks.zsh
