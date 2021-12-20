#!/usr/bin/env lua

local path = require("path")
local cwd = path.abs(path.parent(arg[0]))
local workspace = path(cwd .. "/../../../../..")
local ksonnet_path = path(cwd .. "/../..")
local cluster = "loki-simple-scalable"

package.path = cwd .. "/../../lib/?.lua;" .. package.path
local helm = require("helm")

local k3d = require("k3d").new(cluster)
k3d:prepare()

helm.upgrade("promtail", "promtail", workspace .. "/grafana/helm-charts/charts/promtail", cwd .. "/promtail.yaml")

helm.upgrade(
	"loki",
	"loki-simple-scalable",
	workspace .. "/grafana/helm-charts/charts/loki-simple-scalable",
	cwd .. "/loki.yaml"
)

helm.upgrade("minio", "minio", "minio/minio", cwd .. "/minio.yaml")

helm.upgrade("grafana", "grafana", workspace .. "/grafana/helm-charts/charts/grafana", cwd .. "/grafana.yaml")

-- Install jaeger
k3d:create_namespace("jaeger")
local kPort = k3d:get_server_port()

local tanka = require("tanka").new(ksonnet_path)
local jaegerEnv = "environments/jaeger"
tanka:set_server_port(kPort, jaegerEnv)
tanka:apply(jaegerEnv)

-- Install prometheus
helm.upgrade("prometheus", "prometheus", "prometheus-community/prometheus", ksonnet_path .. "/lib/helm/prometheus.yaml")
