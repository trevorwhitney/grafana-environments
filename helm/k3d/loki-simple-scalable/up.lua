#!/usr/bin/env lua

local workspace = os.getenv("HOME") .. "/workspace"
package.path = workspace .. "/grafana/environments/helm/k3d/lib/?.lua;" .. package.path
local helm = require("helm")
local k3d = require("k3d")
local util = require("util")
local cwd = util.cwd()

k3d.prepare("loki-simple-scalable")

helm.upgrade(
	"logs",
	"loki-simple-scalable",
	workspace .. "/grafana/helm-charts/charts/loki-simple-scalable",
	helm.cwd() .. "/loki.yaml"
)

helm.upgrade(
	"promtail",
	"promtail",
	workspace .. "/grafana/helm-charts/charts/promtail",
	helm.cwd() .. "/promtail.yaml"
)

helm.upgrade("minio", "minio", "minio/minio", cwd .. "/minio.yaml")

helm.upgrade("grafana", "grafana", workspace .. "/grafana/helm-charts/charts/grafana", cwd .. "/grafana.yaml")

helm.upgrade("jaeger", "jaeger", "jaegertracing/jaeger", cwd .. "/jaeger.yaml")

helm.upgrade("prometheus", "prometheus", "prometheus-community/prometheus", cwd .. "/prometheus.yaml")

helm.upgrade(
	"prometheus",
	"kube-state-metrics",
	"prometheus-community/kube-state-metrics",
	cwd .. "/kube-state-metrics.yaml"
)
