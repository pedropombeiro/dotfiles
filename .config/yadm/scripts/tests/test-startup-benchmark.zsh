#!/usr/bin/env zsh

emulate -LR zsh
setopt err_exit
source "${0:A:h:h}/lib/startup-benchmark.zsh"
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/startup-benchmark-test.XXXXXXXX")
trap 'rm -rf -- "$sandbox"' EXIT
fail() { print -ru2 -- "FAIL: $*"; exit 1; }
_update_warn() { warnings+=("$*"); }
_update_note() { notes+=("$*"); }
warnings=() notes=()
print '{"results":[{"median":0.1}]}' > "$sandbox/v1.json"
print '{"results":[{"summary":{"time_wall_clock":{"median":0.2}}}]}' > "$sandbox/v2.json"
print '{"results":[{"median":null}]}' > "$sandbox/bad.json"
[[ $(hyperfine_median "$sandbox/v1.json") == 0.1 ]] || fail 'Hyperfine 1 parsing'
[[ $(hyperfine_median "$sandbox/v2.json") == 0.2 ]] || fail 'Hyperfine 2 parsing'
if hyperfine_median "$sandbox/bad.json"; then fail 'null accepted'; fi
print -l 0.1 0.2 null invalid > "$sandbox/history"
read_benchmark_history "$sandbox/history"
[[ ${#reply} == 2 ]] || fail 'invalid samples retained'
[[ $(benchmark_history_median "$sandbox/history") == 0.15000000000000002 ]] || fail 'median'
append_benchmark_history "$sandbox/history" 0.3 2
[[ $(<"$sandbox/history") == $'0.2\n0.3' ]] || fail 'history trimming'
report_benchmark test 0.5 0.4 "$sandbox/history" 2
[[ ${#warnings} == 2 && $notes[1] == *'rolling median'* ]] || fail 'regression warnings'
print 0.7 > "$sandbox/legacy"
migrate_legacy_benchmark_history "$sandbox/new/history" "$sandbox/legacy"
[[ $(<"$sandbox/new/history") == 0.7 ]] || fail 'migration'
hyperfine() { return 1; }
run_startup_benchmark test 1 "$sandbox/history" command
[[ ${#warnings} == 3 && $(<"$sandbox/history") == $'0.2\n0.3\n0.5' ]] || fail 'failed benchmark modified history'
print 'PASS: benchmark parsing, history, migration, warnings, and failed runs'
