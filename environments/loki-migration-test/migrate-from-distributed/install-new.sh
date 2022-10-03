#!/bin/bash
current_dir=$(cd "$(dirname "$0")" && pwd)
helm_dir=$(cd "${current_dir}/../../../../loki/production/helm/loki" || exit 1 && pwd)

helm install loki ${helm_dir} \
	--namespace loki \
	--values "${current_dir}/new-loki-values.yaml"
