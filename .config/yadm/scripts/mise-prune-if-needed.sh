#!/usr/bin/env bash

YADM_SCRIPTS=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "${YADM_SCRIPTS}/colors.sh"

threshold_gb=${MISE_PRUNE_THRESHOLD_GB:-5}
threshold_kb=$((threshold_gb * 1024 * 1024))

prunable_paths=$(mise ls --prunable --json | jq -r '.. | objects | .install_path? // empty' | sort -u)

if [[ -z ${prunable_paths} ]]; then
  exit 0
fi

prunable_kb=0
while IFS= read -r path; do
  if [[ -d ${path} ]]; then
    size_kb=$(du -sk "${path}" 2>/dev/null | awk '{print $1}')
    prunable_kb=$((prunable_kb + size_kb))
  fi
done <<< "${prunable_paths}"

if (( prunable_kb < threshold_kb )); then
  exit 0
fi

prunable_mb=$((prunable_kb / 1024))
threshold_mb=$((threshold_kb / 1024))

printf "${YELLOW}%s${NC}\n" "Pruning mise (prunable size: ${prunable_mb}MB, threshold: ${threshold_mb}MB)..."
printf "${YELLOW}%s${NC}\n" "Mise prune dry-run report:"
mise prune --tools --dry-run
mise prune --tools --yes
