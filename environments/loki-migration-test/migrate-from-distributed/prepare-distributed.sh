#!/bin/bash
current_dir=$(cd "$(dirname "$0")" && pwd)

helm upgrade loki-distributed grafana/loki-distributed \
	--namespace loki \
  --values "${current_dir}/new-distributed-values.yaml"
