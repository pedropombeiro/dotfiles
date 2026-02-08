#!/bin/bash
# GDK Workspace Launcher for Ghostty
# Creates a multi-tab GDK development environment
#
# Usage: Run directly or bind to Cmd+G in Ghostty

set -e

GDK_DIR="$HOME/gitlab-development-kit"
GDK_GITLAB="$GDK_DIR/gitlab"

# Function to open a new Ghostty tab with a command
open_tab() {
  local title="$1"
  local dir="$2"
  local cmd="$3"
  
  if [[ -n "$cmd" ]]; then
    ghostty --title="$title" --working-directory="$dir" -e bash -c "$cmd; exec zsh"
  else
    ghostty --title="$title" --working-directory="$dir"
  fi
}

# Tab 1: Default (home directory) - this is the current tab
cd "$HOME"

# Tab 2: GDK (gitlab directory + PATH export)
open_tab "GDK" "$GDK_GITLAB" 'export PATH="$PWD/bin:$PATH"; exec zsh' &

# Tab 3: GDK rails console
open_tab "GDK rails console" "$GDK_GITLAB" 'mise x ruby -- bin/spring rails console' &

# Tab 4: GDK development logs
open_tab "GDK development logs" "$GDK_GITLAB" '/opt/homebrew/bin/lnav log/development.log' &

# Tab 5: GDK Postgres console  
open_tab "GDK Postgres console" "$GDK_GITLAB" "/opt/homebrew/bin/pgcli -U pedropombeiro -d gitlabhq_development_ci -h $GDK_DIR/postgresql" &

# Tab 6: ClickHouse client
open_tab "Clickhouse client" "$HOME/clickhouse" '/opt/homebrew/bin/clickhouse client --port 9001 -d gitlab_clickhouse_development' &

echo "GDK workspace launched!"
