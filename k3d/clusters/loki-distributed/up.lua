#!/usr/bin/env lua

local path = require("path")
local cwd = path.abs(path.parent(arg[0]))
local workspace = path(cwd .. "/../../../../..")

package.path = path(cwd .. "/../../lib/?.lua;") .. package.path
local helm = require("helm")
local k3d = require("k3d")

k3d.prepare("loki-distributed")

helm.upgrade("promtail", "promtail", workspace .. "/grafana/helm-charts/charts/promtail", cwd .. "/promtail.yaml")

helm.upgrade(
	"loki",
	"loki-distributed",
	workspace .. "/grafana/helm-charts/charts/loki-distributed",
	cwd .. "/loki.yaml"
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
