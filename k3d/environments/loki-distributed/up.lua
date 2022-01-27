#!/usr/bin/env lua

local path = require("path")

local cwd = path.abs(path.parent(arg[0]))
local workspace = path(cwd .. "/../../../../..")
local ksonnet_path = path(cwd .. "/../..")
local cluster_name = "loki-distributed"

package.path = path(cwd .. "/../../lib/?.lua;") .. package.path
local tanka = require("tanka")
local k3d = require("k3d")

local cluster = k3d.new(cluster_name, "loki-distributed")

cluster:prepare()

local force_build = true
cluster:build_loki_image(path(workspace .. "/grafana/loki"), force_build)

local kPort = cluster:get_server_port()
local tk = tanka.new(ksonnet_path, cluster_name, kPort)
tk:apply()
