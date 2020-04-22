#!/usr/bin/env zsh

if command -v docker > /dev/null; then
  plugins+=(docker docker-compose)
fi

if command -v docker-machine > /dev/null; then
  plugins+=(docker docker-compose)
fi
