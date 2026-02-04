#!/usr/bin/env zsh

# Override rake-fast's _rake_generate to use bundle exec when a Gemfile exists.
# This ensures rake tasks are executed in the correct Bundler context.
#
# Source this file AFTER loading OMZP::rake-fast (e.g., via zinit's atload ice).

_rake_generate() {
  local rake_tasks_content=$'version:'$_rake_tasks_version$'\n'
  local -a rake_cmd

  # Use bundle exec when Gemfile exists to ensure correct gem versions
  if [[ -f "Gemfile" ]]; then
    rake_cmd=(bundle exec rake)
  else
    rake_cmd=(rake)
  fi

  rake_tasks_content+=$(${rake_cmd[@]} --silent --tasks --all 2>/dev/null \
    | sed "s/^rake //" | sed "s/\:/\\\:/g" \
    | sed "s/\[[^]]*\]//g" \
    | sed "s/ *# /\:/" \
    | sed "s/\:$//")

  local rake_tasks_file="$(mktemp -t .rake_tasks.XXXXXX)"
  print -r -- "$rake_tasks_content" > $rake_tasks_file

  mv $rake_tasks_file .rake_tasks
}

# Enable completion for rake and bundle exec rake
compdef _rake rake be

_bundle_exec_rake_completion() {
  if [[ ${words[2]} == exec && ${words[3]} == rake ]]; then
    _rake
  else
    _files
  fi
}

if (( ! $+functions[_bundle] )); then
  compdef _bundle_exec_rake_completion bundle
fi
