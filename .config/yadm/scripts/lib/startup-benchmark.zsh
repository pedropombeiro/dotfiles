#!/usr/bin/env zsh

is_benchmark_value() {
  [[ "$1" =~ '^[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$' ]]
}

read_benchmark_history() {
  local history_file=$1 line
  reply=()
  [[ -f $history_file ]] || return 0
  while IFS= read -r line; do
    is_benchmark_value "$line" && reply+=("$line")
  done < "$history_file"
  return 0
}

# Hyperfine 2 nests statistics under summary.time_wall_clock; 1.x uses median.
hyperfine_median() {
  local median
  median=$(jq -er '.results[0] | (.summary.time_wall_clock.median // .median) | numbers' "$1" 2>/dev/null) || return 1
  is_benchmark_value "$median" || return 1
  printf '%s\n' "$median"
}

run_startup_benchmark() {
  local label=$1 hard_limit=$2 history_file=$3 export_file median
  shift 3
  export_file=$(mktemp)
  if hyperfine "$@" --export-json "$export_file" && median=$(hyperfine_median "$export_file"); then
    report_benchmark "$label" "$median" "$hard_limit" "$history_file"
  else
    _update_warn "${label} benchmark failed or produced no median; skipping history update."
  fi
  rm -f "$export_file"
}

benchmark_history_median() {
  local history_file=$1 max_samples=${2:-10}
  local -a values
  read_benchmark_history "$history_file"
  values=("${reply[@]}")
  (( ${#values} )) || return 1
  if (( ${#values} > max_samples )); then
    values=("${values[@]: -max_samples}")
  fi
  printf '%s\n' "${values[@]}" | python3 -c 'import statistics, sys; print(statistics.median(float(line) for line in sys.stdin))'
}

append_benchmark_history() {
  local history_file=$1 benchmark=$2 max_samples=${3:-10}
  local -a values
  mkdir -p "${history_file:h}"
  read_benchmark_history "$history_file"
  values=("${reply[@]}" "$benchmark")
  if (( ${#values} > max_samples )); then
    values=("${values[@]: -max_samples}")
  fi
  printf '%s\n' "${values[@]}" > "$history_file"
}

migrate_legacy_benchmark_history() {
  local history_file=$1 legacy_file=$2
  [[ -f $legacy_file ]] || return 0
  [[ -f $history_file ]] && return 0
  mkdir -p "${history_file:h}"
  cp "$legacy_file" "$history_file"
}

report_benchmark() {
  local label=$1 benchmark=$2 hard_limit=$3 history_file=$4
  local baseline_min_samples=${5:-5} history_samples baseline_median note
  read_benchmark_history "$history_file"
  history_samples=${#reply}
  note=$(printf 'median %.0fms' $(( benchmark * 1000 )))
  if (( benchmark >= hard_limit )); then
    _update_warn "${label} startup time exceeded hard limit ($(printf '%.0f' $(( hard_limit * 1000 )))ms)."
  fi
  if (( history_samples >= baseline_min_samples )); then
    baseline_median=$(benchmark_history_median "$history_file")
    if [[ -n $baseline_median ]]; then
      note+=$(printf ', rolling median %.0fms over %d runs' $(( baseline_median * 1000 )) "$history_samples")
      if (( benchmark >= baseline_median * 1.1 )); then
        _update_warn "${label} startup time increased over 10% compared to rolling median."
      fi
    fi
  else
    note+=$(printf ', collecting baseline (%d/%d runs)' "$history_samples" "$baseline_min_samples")
  fi
  _update_note "$note"
  append_benchmark_history "$history_file" "$benchmark"
}
