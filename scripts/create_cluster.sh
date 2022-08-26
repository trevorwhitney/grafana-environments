#!/bin/bash
set -x

environment="$1"
cluster_name="$(basename "$1")"
registry_port="$2"
namespace="k3d-${cluster_name}"

k3d cluster create "${cluster_name}" \
	--servers 1 \
	--agents 3 \
  --volume /home/twhitney/workspace/grafana/gex-plugins/plugins/grafana-enterprise-logs-app:/var/lib/grafana/plugins/grafana-enterprise-logs-app \
	--registry-use "k3d-grafana:${registry_port}" \
	--wait || true

tk env set "${environment}" \
	--server="https://0.0.0.0:$(k3d node list -o json | jq -r ".[] | select(.name == \"k3d-${cluster_name}-serverlb\") | .portMappings.\"6443\"[] | .HostPort")" \
	--namespace="${namespace}"

kubectl config set-context "${namespace}"

if ! kubectl get namespaces | grep -q -m 1 "${namespace}"; then
	kubectl create namespace "${namespace}" || true
fi

# Apply CRDs needed for prometheus operator
prometheus_crd_base_url="https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.52.0/example/prometheus-operator-crd"
for file in monitoring.coreos.com_alertmanagerconfigs.yaml \
	monitoring.coreos.com_alertmanagers.yaml \
	monitoring.coreos.com_podmonitors.yaml \
	monitoring.coreos.com_probes.yaml \
	monitoring.coreos.com_prometheuses.yaml \
	monitoring.coreos.com_prometheusrules.yaml \
	monitoring.coreos.com_servicemonitors.yaml \
	monitoring.coreos.com_thanosrulers.yaml; do
	kubectl apply \
		-f "${prometheus_crd_base_url}/${file}" \
		--force-conflicts=true \
		--server-side
done

# Apply CRDs needed for grafana agent
agent_crd_base_url="https://raw.githubusercontent.com/grafana/agent/main/production/operator/crds"
for file in monitoring.coreos.com_podmonitors.yaml \
	monitoring.coreos.com_probes.yaml \
	monitoring.coreos.com_servicemonitors.yaml \
	monitoring.grafana.com_grafanaagents.yaml \
	monitoring.grafana.com_integrations.yaml \
	monitoring.grafana.com_logsinstances.yaml \
	monitoring.grafana.com_metricsinstances.yaml \
	monitoring.grafana.com_podlogs.yaml; do
	kubectl apply \
		-f "${agent_crd_base_url}/${file}" \
		--force-conflicts=true \
		--server-side
done

# Sleep for 5s to make sure the cluster is ready
sleep 5
tk apply "${environment}"
