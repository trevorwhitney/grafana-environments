#!/bin/bash

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SRC_DEST="${SCRIPT_DIR}/.src/"

# sync all sources for dlv
rm -Rf "${SRC_DEST}"
mkdir "${SRC_DEST}"
for d in cmd pkg vendor clients
do
    cp -Rf "${SCRIPT_DIR}/../../loki/${d}/" "${SRC_DEST}/${d}/"
done

# build loki -gcflags "all=-N -l" disables optimizations that allow for better run with combination with Delve debugger.
pushd "${SCRIPT_DIR}/../../loki"
  pwd
  echo 'building loki'
  CGO_ENABLED=0 GOOS=linux go build -mod=vendor -gcflags "all=-N -l" -o "${SCRIPT_DIR}/loki" "./cmd/loki"
popd

# ## install loki driver to send logs
docker plugin install grafana/loki-docker-driver:latest --alias loki-compose --grant-all-permissions || true
# build the compose image
docker-compose -f "${SCRIPT_DIR}"/docker-compose.yaml build read
# cleanup sources
rm -Rf "${SRC_DEST}"

set +e
op list items 2>&1 > /dev/null 
if [[ $? -ne 0 ]]; then
  eval "$(op signin my)"
fi
set -e

grafana_com_logs=$(op get item grafana-com-logs | jq '.details.sections | .[].fields')
logs_hostname=$(echo "$grafana_com_logs" | jq -r '.[] | select(.n == "hostname") | .v')
logs_user=$(echo "$grafana_com_logs" | jq -r '.[] | select(.n == "username") | .v')
logs_token=$(echo "$grafana_com_logs" | jq -r '.[] | select(.n == "credential") | .v')

LOGS_URL="https://${logs_user}:${logs_token}@${logs_hostname}/loki/api/v1/push" docker-compose -f "${SCRIPT_DIR}"/docker-compose.yaml up "$@"
