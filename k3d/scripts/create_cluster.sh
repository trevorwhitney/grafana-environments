#!/bin/bash
set -x

environment="$1"
cluster_name="$(basename "$1")"
registry_port="$2"
namespace="k3d-${cluster_name}"

k3d cluster create "${cluster_name}" \
	--servers 1 \
	--agents 3 \
	--registry-use "k3d-grafana:${registry_port}" \
	--wait || true

tk env set "${environment}" \
	--server="https://0.0.0.0:$(k3d node list -o json | jq -r ".[] | select(.name == \"k3d-${cluster_name}-serverlb\") | .portMappings.\"6443\"[] | .HostPort")" \
	--namespace="${namespace}"

kubectl config set-context "${namespace}"

if ! kubectl get namespaces | grep -q -m 1 "${namespace}"; then
	kubectl create namespace "${namespace}" || true
fi

# Sleep for 5s to make sure the cluster is ready
sleep 5
tk apply "${environment}"
