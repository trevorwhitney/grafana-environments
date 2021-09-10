#!/usr/bin/env zsh

docker-compose -f docker-compose.yaml up \
  --force-recreate \
  --remove-orphans 2>&1 | lnav -t

# this will wait until lnav has been quit
docker-compose -f docker-compose.yaml down --remove-orphans
