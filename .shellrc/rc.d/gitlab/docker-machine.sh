#!/usr/bin/env bash

dockerVMName='docker-parallels'
if command -v docker-machine &>/dev/null; then
  if [ "$(docker-machine status "${dockerVMName}")" != "Running" ]; then
    # Ensure docker VM is started
    docker-machine start "${dockerVMName}"
    # Install QEMU handlers
    docker run --rm --privileged docker/binfmt:a7996909642ee92942dcd6cff44b9b95f08dad64
  fi

  [[ -f ~/.docker-machine.env ]] || docker-machine env "${dockerVMName}" > ~/.docker-machine.env
  # Configure default docker-machine VM
  source ~/.docker-machine.env
fi
