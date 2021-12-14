#!/usr/bin/env lua

local path = require("path")
local cwd = path.abs(path.parent(arg[0]))
local workspace = path(cwd .. "/../../../../..")

package.path = cwd .. "/../../lib/?.lua;" .. package.path
local helm = require("helm")
local k3d = require("k3d")

k3d.prepare("loki-simple-scalable")

helm.upgrade("promtail", "promtail", workspace .. "/grafana/helm-charts/charts/promtail", cwd .. "/promtail.yaml")

helm.upgrade(
	"loki",
	"loki-simple-scalable",
	workspace .. "/grafana/helm-charts/charts/loki-simple-scalable",
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
