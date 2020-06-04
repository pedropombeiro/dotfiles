#!/usr/bin/env bash

if command -v docker-machine &>/dev/null; then
  if [ "$(docker-machine status docker)" = "Running" ]; then
    # Configure default docker-machine VM
    eval "$(docker-machine env docker)"
  else
    # Ensure docker VM is started
    docker-machine start docker
    # Configure default docker-machine VM
    eval "$(docker-machine env docker)"
    # Install QEMU handlers
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
  fi
fi
