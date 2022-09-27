#!/bin/bash
current_dir=$(cd "$(dirname "$0")" && pwd)

helm install loki grafana/loki-distributed \
	--namespace loki \
	--values "${current_dir}/values.yaml"
