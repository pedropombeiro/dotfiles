#!/usr/bin/env bash

[ -d "/usr/local/bin/orka" ] && export PATH="${PATH}:/usr/local/bin/orka"

alias oil="orka image list"
alias ovl="orka vm list"
alias oid="orka image delete -y --image"
alias ovp="orka vm purge -y --vm"
alias oquota="orka image list --json | jq '[ .image_attributes[] | .image_size | rtrimstr(\"G\") | tonumber ] | add'"

function opmr() {
  local MR="$1"
  if [[ -z ${MR} ]]; then
    echo "Please specify the MR number as an argument"
    return
  fi

  orka image list --json | \
    jq -r ".images[] | select(contains(\"mr-${MR}\"))" | \
    xargs -I{} orka image delete -y --image {}
}

function ovpa() {
  orka vm list --json | \
    jq -r ".virtual_machine_resources[] | .status[] | .virtual_machine_id" | \
    xargs -I{} orka vm purge -y --vm {}
}
