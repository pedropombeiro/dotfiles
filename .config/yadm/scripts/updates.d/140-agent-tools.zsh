#!/usr/bin/env zsh

step_opencode_skills() {
  local opencode_completion="${HOME}/.config/zsh/site-functions/_opencode"
  "${YADM_SCRIPTS}/sync-work-skills.zsh" --update
  # Drop the cached OpenCode 1 completer after upgrading to OpenCode 2.
  if [[ -f ${opencode_completion} && $(<"${opencode_completion}") == *_opencode_yargs_completions* &&
    $(opencode --version 2>/dev/null) == "opencode v"* ]]; then
    rm -f "${opencode_completion}" "${HOME}"/.zcompdump*(N)
  fi
}

step_opencode_telemetry() {
  "${YADM_SCRIPTS}/checks.d/020-opencode-telemetry.zsh" --fix
}

step_skill_repositories() {
  mise bootstrap repos update --yes --skip-dirty "${HOME}/Developer/github.com/pinchtab/pinchtab"
  "${YADM_SCRIPTS}/relink-dotfiles.zsh"
}

_update_register "opencode skills" step_opencode_skills
_update_register "opencode telemetry" step_opencode_telemetry
_update_register "skill repositories" step_skill_repositories
