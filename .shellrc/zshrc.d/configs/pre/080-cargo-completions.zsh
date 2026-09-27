#!/usr/bin/env zsh

# Copy cargo completions to site-functions from mise or rustup installs
_cargo_dst="$HOME/.config/zsh/site-functions/_cargo"
if [[ ! -s "$_cargo_dst" ]]; then
  # Try mise installs first, then rustup
  _cargo_src=(
    ~/.local/share/mise/installs/rust/*/toolchains/*/share/zsh/site-functions/_cargo(N)
    ~/.rustup/toolchains/*/share/zsh/site-functions/_cargo(N)
  )
  # Sort paths by name, descending.
  _cargo_src=(${(On)_cargo_src})
  if [[ -n "$_cargo_src[1]" && -f "$_cargo_src[1]" ]]; then
    _cargo_tmp="${_cargo_dst}.tmp.$$"
    if cp "$_cargo_src[1]" "$_cargo_tmp" && [[ -s "$_cargo_tmp" ]]; then
      mv -f -- "$_cargo_tmp" "$_cargo_dst"
    else
      rm -f -- "$_cargo_tmp"
    fi
    unset _cargo_tmp
  fi
  unset _cargo_src
fi
unset _cargo_dst
