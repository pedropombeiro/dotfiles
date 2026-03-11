#!/usr/bin/env zsh

spring_binstubs() {
  local action=${1}
  local repo=${2:-.}
  local -a files

  files=(bin/rails bin/rake bin/rspec bin/spring)

  case "${action}" in
    restore)
      (
        cd "${repo}" || return 0
        git update-index --no-skip-worktree -- "${files[@]}" 2>/dev/null || true
        git restore -- "${files[@]}" 2>/dev/null || true
      )
      ;;
    generate)
      (
        cd "${repo}" || return 0
        if [[ -x bin/spring ]]; then
          mise x ruby -- bin/spring binstub --all
        fi
        git update-index --skip-worktree -- "${files[@]}" 2>/dev/null || true
      )
      ;;
    ensure)
      (
        cd "${repo}" || return 0
        git update-index --skip-worktree -- "${files[@]}" 2>/dev/null || true
      )
      ;;
    *)
      printf 'usage: spring_binstubs {restore|generate|ensure} [repo]\n'
      return 1
      ;;
  esac
}
