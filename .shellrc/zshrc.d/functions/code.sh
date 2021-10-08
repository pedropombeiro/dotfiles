#!/usr/bin/env bash

function killvscode() {
  (
    for p in 'Code Helper (Renderer)' 'gopls'; do
      echo -n "Killing ${p}: "
      killall "${p}" && echo "Success"
    done
  )
}
