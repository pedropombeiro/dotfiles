#!/usr/bin/env zsh
# Test approval selection and app lifecycle without launching real software.
emulate -LR zsh
setopt err_exit

source "${0:A:h}/approve-quarantined.zsh"
local sandbox=$(mktemp -d "${TMPDIR:-/tmp}/download-approval-test.XXXXXXXX")
trap 'rm -rf -- "$sandbox"' EXIT
local -a calls warnings
local mock_quarantine='0181;test'
local app_pid='' quit_response=yes
local pid_rc=0

fail() { print -u2 -- "FAIL: $*"; exit 1; }
_update_warn() { warnings+=("$*"); }
xattr() { print -r -- "$mock_quarantine"; }
approval_apps() {
  case $1 in
    list) print /Applications/Existing.app ;;
    pid) print -r -- "$app_pid"; return $pid_rc ;;
    quit) print -r -- "$*" >> "$sandbox/quit"; print -r -- "$quit_response" ;;
  esac
}
open() { calls+=("$*"); app_pid=42; }
timeout() { calls+=("$*"); return ${timeout_rc:-0}; }

for mock_quarantine in '0181;test' '0381;test'; do
  approval_needed /mock || fail "unapproved flag: $mock_quarantine"
done
for mock_quarantine in '' '01c1;test' '03c1;test' 'invalid;test'; do
  if approval_needed /mock; then fail "approved or invalid flag: $mock_quarantine"; fi
done
print 'PASS: quarantine flags'

mock_quarantine='0381;test'
approve_app '/Applications/Existing.app' $'/Applications/Other.app\n/Applications/Existing.app'
(( ${#calls} == 0 )) || fail 'opened an initially running app'
app_pid=99
approve_app '/Applications/Started Later.app' '/Applications/Existing.app'
(( ${#calls} == 0 )) || fail 'opened a currently running app'
app_pid=''
approve_app '/Applications/New App.app' '/Applications/Existing.app'
[[ $calls[1] == '-gj /Applications/New App.app' ]] || fail 'did not open new app'
[[ $(<"$sandbox/quit") == 'quit /Applications/New App.app 42' ]] || fail 'did not quit new process'
print 'PASS: preserve running apps and quit new apps'

calls=() warnings=() app_pid=''
approve_app '/Applications/Unknown.app' ''
(( ${#calls} == 0 && ${#warnings} == 1 )) || fail 'missing app state was not handled safely'
quit_response=no
approve_app '/Applications/Refuses Quit.app' '/Applications/Existing.app'
(( ${#warnings} == 2 )) || fail 'quit refusal was not reported'
print 'PASS: app-state and termination failures'

calls=() warnings=() app_pid='' pid_rc=1
approve_app '/Applications/State Failure.app' '/Applications/Existing.app'
(( ${#calls} == 0 && ${#warnings} == 1 )) || fail 'running-state query failure launched an app'
pid_rc=0 mock_quarantine='01c1;test'
approve_app '/Applications/Approved.app' '/Applications/Existing.app'
(( ${#calls} == 0 )) || fail 'opened an approved app'
print 'PASS: skip approved apps and failed running-state queries'

touch "$sandbox/tool with spaces"
chmod +x "$sandbox/tool with spaces"
calls=() warnings=()
approve_binary "$sandbox/tool with spaces"
[[ $calls[1] == "120 $sandbox/tool with spaces --version" ]] || fail 'wrong executable check'
timeout_rc=124
approve_binary "$sandbox/tool with spaces"
(( ${#warnings} == 1 )) || fail 'timeout was not reported'
print 'PASS: CLI check and timeout warnings'

cat > "$sandbox/before.json" <<'JSON'
{"casks":[{"token":"unchanged","installed":"1"},{"token":"upgraded","installed":"1"}]}
JSON
jq -n --arg target "$sandbox/tool with spaces" '{casks: [
  {token: "unchanged", installed: "1", artifacts: [{binary: ["skip"], target: "/skip"}]},
  {token: "upgraded", installed: "2", artifacts: [{binary: ["tool"], target: $target}]},
  {token: "new", installed: "1", artifacts: [{app: ["New.app"], target: "/Applications/New.app"}]},
  {token: "not-installed", installed: null, artifacts: [{binary: ["skip"], target: "/skip"}]}
]}' > "$sandbox/after.json"
brew() { cat "$sandbox/after.json"; }
approve_app() { calls+=("app $1"); }
approve_binary() { calls+=("binary $1"); }
calls=() warnings=()
approve_casks "$sandbox/before.json" '/Applications/Existing.app'
(( ${#calls} == 2 )) || fail 'wrong changed-artifact count'
[[ $calls[1] == "binary $sandbox/tool with spaces" ]] || fail 'upgraded binary not selected'
[[ $calls[2] == 'app /Applications/New.app' ]] || fail 'installed app not selected'
calls=()
approve_casks "$sandbox/missing.json" '/Applications/Existing.app'
(( ${#calls} == 0 && ${#warnings} == 1 )) || fail 'missing snapshot was not handled safely'
print 'PASS: select only casks changed this run'
