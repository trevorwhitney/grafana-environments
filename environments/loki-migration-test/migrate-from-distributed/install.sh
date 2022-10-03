#!/bin/bash
current_dir=$(cd "$(dirname "$0")" && pwd)

kubectl create namespace loki || true
helm install loki-distributed grafana/loki-distributed \
	--namespace loki \
	--values "${current_dir}/loki-values.yaml"

helm install promtail grafana/promtail \
  --namespace loki \
  --values "${current_dir}/promtail-values.yaml"

helm install canary grafana/loki-canary \
  --namespace loki \
  --values "${current_dir}/canary-values.yaml"
