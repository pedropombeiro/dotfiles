#!/usr/bin/env zsh

# Copy cargo completions to site-functions from mise rust install
_cargo_dst="$HOME/.config/zsh/site-functions/_cargo"
if [[ ! -f "$_cargo_dst" ]]; then
  # Find newest _cargo completion file from mise rust installs
  _cargo_src=(~/.local/share/mise/installs/rust/*/toolchains/*/share/zsh/site-functions/_cargo(Nom[1]))
  if [[ -n "$_cargo_src" && -f "$_cargo_src" ]]; then
    cp "$_cargo_src" "$_cargo_dst"
    rm -f ~/.zcompdump* 2>/dev/null
  fi
  unset _cargo_src
fi
unset _cargo_dst
