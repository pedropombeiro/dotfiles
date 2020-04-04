if [ command -v rbenv >/dev/null 2>&1 ]; then
  export PATH="$HOME/.rbenv/bin:$PATH"
  eval "$(rbenv init -)"
fi
