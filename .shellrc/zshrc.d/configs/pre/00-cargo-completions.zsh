#!/usr/bin/env zsh

# Copy cargo completions to site-functions from mise or rustup installs
_cargo_dst="$HOME/.config/zsh/site-functions/_cargo"
if [[ ! -f "$_cargo_dst" ]]; then
  # Try mise installs first, then rustup
  _cargo_src=(
    ~/.local/share/mise/installs/rust/*/toolchains/*/share/zsh/site-functions/_cargo(N)
    ~/.rustup/toolchains/*/share/zsh/site-functions/_cargo(N)
  )
  # Sort by modification time, newest first
  _cargo_src=(${(On)_cargo_src})
  if [[ -n "$_cargo_src[1]" && -f "$_cargo_src[1]" ]]; then
    cp "$_cargo_src[1]" "$_cargo_dst"
    rm -f ~/.zcompdump* 2>/dev/null
  fi
  unset _cargo_src
fi
unset _cargo_dst
