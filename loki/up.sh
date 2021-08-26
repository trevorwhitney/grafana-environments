#!/usr/bin/env zsh

docker-compose -f docker-compose.yaml up \
  --force-recreate \
  --remove-orphans 2>&1 | lnav -t
