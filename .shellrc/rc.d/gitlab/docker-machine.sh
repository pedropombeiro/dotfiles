#!/usr/bin/env bash

if command -v docker-machine &>/dev/null; then
  # Configure default docker-machine VM
  eval "$(docker-machine env docker)"
fi
