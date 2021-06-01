#!/usr/bin/env bash

export RAILS_HOSTS="127.0.0.1,localhost,host.docker.internal,gdk.localhost"
GDK_ROOT="${HOME}/src/gitlab-development-kit"
[[ -d ${GDK_ROOT} ]] && export GDK_ROOT
