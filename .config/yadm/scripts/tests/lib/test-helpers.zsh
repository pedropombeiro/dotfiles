#!/usr/bin/env zsh

# Source after resolving production paths, before creating fixtures.
test_fail() {
  print -ru2 -- "FAIL: $*"
  exit 1
}

test_sandbox() {
  local tool name
  # Resolve tools without mise shims, which read host configuration after HOME
  # changes. Keep package-manager paths available while locating dependencies.
  local -a search_path=("${(@)path:#*/mise/shims}")
  typeset -g TEST_SANDBOX
  TEST_SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/yadm-test.XXXXXXXX") || test_fail 'could not create sandbox'
  TEST_SANDBOX=${TEST_SANDBOX:A}
  mkdir -p "$TEST_SANDBOX"/{bin,home,work,tmp,config,cache,data,state}
  for tool in zsh git diff "$@"; do
    local resolved=$(PATH="${(j/:/)search_path}" whence -p "$tool")
    [[ -n $resolved ]] || test_fail "missing non-shim test dependency: $tool"
    ln -sf -- "$resolved" "$TEST_SANDBOX/bin/$tool"
  done
  # Drop inherited repository and runtime settings, including alternate Git
  # indexes and mise config paths. Suites can set fixture-specific values later.
  for name in ${(k)parameters}; do
    case $name in
      GIT_*|MISE_*) unset "$name" ;;
    esac
  done
  export HOME="$TEST_SANDBOX/home" ZDOTDIR="$TEST_SANDBOX/home"
  export XDG_CONFIG_HOME="$TEST_SANDBOX/config" XDG_CACHE_HOME="$TEST_SANDBOX/cache"
  export XDG_DATA_HOME="$TEST_SANDBOX/data" XDG_STATE_HOME="$TEST_SANDBOX/state"
  export TMPDIR="$TEST_SANDBOX/tmp"
  export PATH="$TEST_SANDBOX/bin:/usr/bin:/bin"
  export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
  cd "$TEST_SANDBOX/work"
}

test_cleanup() {
  cd /
  [[ -n ${TEST_SANDBOX:-} ]] && rm -rf -- "$TEST_SANDBOX"
}

# Usage: test_stub command <<'SCRIPT' ... SCRIPT
test_stub() {
  # Never write through a dependency symlink into the real tool.
  [[ ! -L $TEST_SANDBOX/bin/$1 ]] || unlink "$TEST_SANDBOX/bin/$1"
  cat > "$TEST_SANDBOX/bin/$1"
  chmod +x "$TEST_SANDBOX/bin/$1"
}

# Arguments are case name, expected status, and the command with its arguments.
test_expect_status() {
  local label=$1 expected=$2 actual=0
  shift 2
  "$@" > "$TEST_SANDBOX/output" 2>&1 || actual=$?
  if [[ $actual != $expected ]]; then
    cat "$TEST_SANDBOX/output" >&2
    test_fail "$label: expected exit $expected, got $actual"
  fi
}

test_assert_equal() {
  local label=$1 expected=$2 actual=$3
  [[ $actual == "$expected" ]] && return 0
  print -r -- "$expected" > "$TEST_SANDBOX/expected"
  print -r -- "$actual" > "$TEST_SANDBOX/actual"
  print -ru2 -- "FAIL: $label (expected vs actual)"
  diff -u "$TEST_SANDBOX/expected" "$TEST_SANDBOX/actual" >&2 || true
  exit 1
}
