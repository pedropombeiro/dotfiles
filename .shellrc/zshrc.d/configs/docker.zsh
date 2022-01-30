#!/usr/bin/env zsh

if command -v docker > /dev/null; then
  plugins+=(docker docker-compose)
elif command -v docker-machine > /dev/null; then
  plugins+=(docker docker-compose)
fi
