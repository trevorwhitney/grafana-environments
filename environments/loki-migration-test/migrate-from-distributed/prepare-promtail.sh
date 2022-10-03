#!/bin/bash
current_dir=$(cd "$(dirname "$0")" && pwd)

helm upgrade promtail grafana/promtail \
  --namespace loki \
  --values "${current_dir}/new-promtail-values.yaml"
