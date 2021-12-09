#!/usr/bin/env lua

local workspace = os.getenv("HOME") .. "/workspace"
package.path = workspace .. "/grafana/environments/helm/k3d/lib/?.lua;" .. package.path
local helm = require("helm")
local k3d = require("k3d")

k3d.prepare("loki-simple-scalable")

helm.upgradeOrInstall(
	3,
	"logs",
	"loki-simple-scalable",
	workspace .. "/grafana/helm-charts/charts/loki-simple-scalable",
	helm.cwd() .. "/loki.yaml"
)

helm.upgradeOrInstall(
	1,
	"promtail",
	"promtail",
	workspace .. "/grafana/helm-charts/charts/promtail",
	helm.cwd() .. "/promtail.yaml"
)

helm.upgradeOrInstall(1, "minio", "minio", "minio/minio", helm.cwd() .. "/minio.yaml")

helm.upgradeOrInstall(
	1,
	"grafana",
	"grafana",
	workspace .. "/grafana/helm-charts/charts/grafana",
	helm.cwd() .. "/grafana.yaml"
)

helm.upgradeOrInstall(5, "jaeger", "jaeger", "jaegertracing/jaeger", helm.cwd() .. "/jaeger.yaml")

helm.upgradeOrInstall(
	1,
	"prometheus",
	"prometheus",
	"prometheus-community/prometheus",
	helm.cwd() .. "/prometheus.yaml"
)

helm.upgradeOrInstall(
	1,
	"kube-state-metrics",
	"kube-state-metrics",
	"prometheus-community/kube-state-metrics",
	helm.cwd() .. "/kube-state-metrics.yaml"
)
