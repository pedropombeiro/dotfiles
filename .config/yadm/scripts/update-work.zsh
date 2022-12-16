#!/usr/bin/env zsh

YADM_SCRIPTS=$( cd -- "$( dirname -- ${(%):-%x} )/../scripts" &> /dev/null && pwd )

source "${YADM_SCRIPTS}/colors.sh"

# Ensure Python is allowed to serve HTTP pages, so that the Walking Pad app is accessible to Home Assistant/Grafana
PYTHON_PATH="$(realpath $(brew --prefix)/Frameworks/Python.framework/Versions/Current/Resources/Python.app/Contents/MacOS/Python)"
if [[ -f $PYTHON_PATH ]]; then
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add "${PYTHON_PATH}"
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "${PYTHON_PATH}"
fi

# Populate gdk.yml
if [[ -n ${GDK_ROOT} ]]; then
  cat << EOF > ${GDK_ROOT}/gdk.tmp.yml
---
hostname: gdk.test
port: 3000
runner:
  bin: "${HOME}/src/gitlab.com/gitlab-org/gitlab-runner/out/binaries/gitlab-runner"
  config_file: "${HOME}/.gitlab-runner/config.gdk.toml"
  enabled: false
snowplow_micro:
  enabled: false
  port: 9090
gdk:
  update_hooks:
    before:
      - cd gitlab && scalar register # Improve performance for rebasing/status/etc.
    after:
      - git -C gitlab restore db/structure.sql
  overwrite_changes: true
#https:
#  enabled: true
#nginx:
#  enabled: true
#  ssl:
#    certificate: "${GDK_ROOT}/gdk.localhost+2.pem"
#    key: "${GDK_ROOT}/gdk.localhost+2-key.pem"
trusted_directories:
- "${GDK_ROOT}"
listen_address: 0.0.0.0
#gitlab:
#  rails:
#    sherlock: true
EOF
fi

if ! delta "${GDK_ROOT}/gdk.yml" "${GDK_ROOT}/gdk.tmp.yml"; then
  printf "${YELLOW}%s${NC}\n" "Overwriting gdk.yml. Please rerun 'gdk reconfigure'..."
  cp -f "${GDK_ROOT}/gdk.yml" "${GDK_ROOT}/gdk.prev.yml"
  cp -f "${GDK_ROOT}/gdk.tmp.yml" "${GDK_ROOT}/gdk.yml"
fi
rm -f "${GDK_ROOT}/gdk.tmp.yml"

scalar reconfigure -a

