#!/bin/bash

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SRC_DEST="${SCRIPT_DIR}/.src/"

# sync all sources for dlv
rm -Rf "${SRC_DEST}"
mkdir "${SRC_DEST}"
for d in cmd pkg vendor tools
do
    cp -Rf "${SCRIPT_DIR}/../../backend-enterprise/${d}/" "${SRC_DEST}/${d}/"
done

# build backend-enterprise -gcflags "all=-N -l" disables optimizations that allow for better run with combination with Delve debugger.
pushd "${SCRIPT_DIR}/../../backend-enterprise"
  pwd
  echo 'building enterprise-metrics'
  go mod vendor
  CGO_ENABLED=0 GOOS=linux go build -mod=vendor -gcflags "all=-N -l" -o "${SCRIPT_DIR}/enterprise-metrics" "./cmd/enterprise-metrics"
  pushd "${SCRIPT_DIR}/../../backend-enterprise/tools"
    go mod vendor
    CGO_ENABLED=0 GOOS=linux go build -mod=vendor -gcflags "all=-N -l" -o "${SCRIPT_DIR}/enterprise-metrics-provisioner" "./cmd/enterprise-metrics-provisioner"
  popd
popd

# ## install backend-enterprise driver to send logs
docker plugin install grafana/loki-docker-driver:latest --alias loki-compose --grant-all-permissions || true
# build the compose image
docker-compose -f "${SCRIPT_DIR}"/docker-compose.yaml build enterprise-metrics
# cleanup sources
rm -Rf "${SRC_DEST}"

# make sure we're logged in to 1password
op list items 2>&1 > /dev/null

grafana_com_logs=$(op get item grafana-com-logs | jq '.details.sections | .[].fields')
logs_hostname=$(echo "$grafana_com_logs" | jq -r '.[] | select(.n == "hostname") | .v')
logs_user=$(echo "$grafana_com_logs" | jq -r '.[] | select(.n == "username") | .v')
logs_token=$(echo "$grafana_com_logs" | jq -r '.[] | select(.n == "credential") | .v')

LOGS_URL="https://${logs_user}:${logs_token}@${logs_hostname}/loki/api/v1/push" docker-compose -f "${SCRIPT_DIR}"/docker-compose.yaml up "$@"
