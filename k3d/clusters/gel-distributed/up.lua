#!/usr/bin/env lua

local path = require("path")
local cwd = path.abs(path.parent(arg[0]))
local workspace = path(cwd .. "/../../../../..")
local ksonnet_path = path(cwd .. "/../..")
local cluster = "gel-distributed"

package.path = path(cwd .. "/../../lib/?.lua;") .. package.path
local helm = require("helm")

local k3d = require("k3d").new(cluster)
k3d:prepare()

local tanka = require("tanka").new(ksonnet_path)

-- Install jaeger
k3d:create_namespace("jaeger")
local kPort = k3d:get_server_port()

local jaegerEnv = "environments/jaeger"
tanka:set_server_port(kPort, jaegerEnv)
tanka:apply(jaegerEnv)

-- Install promtail
helm.upgrade("promtail", "promtail", workspace .. "/grafana/helm-charts/charts/promtail", cwd .. "/promtail.yaml")

-- Install gel-distributed
local gel_chart = path(workspace .. "/grafana/helm-charts/charts/enterprise-logs")
helm.update(gel_chart)
helm.upgrade("gel", "gel-distributed", workspace .. "/grafana/helm-charts/charts/enterprise-logs", cwd .. "/gel.yaml")

-- Install grafana
-- TODO: convert to jsonnet, and use enterprise
helm.upgrade("grafana", "grafana", workspace .. "/grafana/helm-charts/charts/grafana", cwd .. "/grafana.yaml")

-- Install prometheus
helm.upgrade("prometheus", "prometheus", "prometheus-community/prometheus", cwd .. "/prometheus.yaml")
