local shell = require("shell-games")

--- @module tanka
local k3d = {}

-- class K3d
local K3d = {}

local function prepareRegistry()
	local registryExists = shell.run_raw("k3d registry list | grep k3d-grafana > /dev/null")
	if not registryExists then
		os.execute("k3d registry create grafana")
	end
end

local function prepareCluster(cluster, nodes)
	local _, err = shell.run_raw("k3d cluster list | grep " .. cluster)
	if err then
		os.execute(
			"k3d cluster create "
				.. cluster
				.. " --registry-use k3d-grafana:45629"
        .. " --servers 1"
        .. " --agents "
        .. nodes
		)
	end
end

local function setContext(cluster)
	local _, err = shell.run({ "kubectl", "config", "set-context", "k3d-" .. cluster })
	if err then
		print(err)
		os.exit(1)
	end

	local result, err2 = shell.run({ "kubectl", "config", "current-context" }, { capture = true })
	if err2 or string.gsub(result.output, "\n", "") ~= "k3d-" .. cluster then
		print("could not switch context")
		os.exit(1)
	end
end

function K3d:get_server_port()
	local result, err = shell.run_raw(
		"k3d node list -o json | "
			.. "jq -r ' .[] | select(.name == \"k3d-"
			.. self.cluster
			.. '-serverlb") | .portMappings."6443"[] | .HostPort\'',
		{ capture = true }
	)

	if err then
		print(err)
		os.exit(1)
	end

	return string.gsub(result.output, "\n", "")
end

local function get_registry_port()
	local registry_port, err = shell.run_raw(
		"k3d registry list k3d-grafana -o json | "
			.. 'jq -r \'.[] | select(.name=="k3d-grafana") | .portMappings."5000/tcp"[0].HostPort\'',
		{
			capture = true,
		}
	)
	if err then
		print(err)
		os.exit(1)
	end

	return string.gsub(registry_port.output, "\n", "")
end

function K3d:prepare()
	prepareRegistry()
	prepareCluster(self.cluster, self.nodes)
	setContext(self.cluster)
	self:create_namespace()

	self.registry_port = get_registry_port()
end

function K3d:build_provisioner_image(backend_enterprise_path)
	local exists = shell.run_raw(
		"docker image ls | grep k3d-grafana:" .. self.registry_port .. "/enterprise-metrics-provisioner"
	)
	if exists then
		return
	end

	shell.run({
		"make",
		"enterprise-metrics-provisioner-image",
	}, {
		chdir = backend_enterprise_path,
	})
	shell.run({
		"docker",
		"tag",
		"us.gcr.io/kubernetes-dev/enterprise-metrics-provisioner",
		"k3d-grafana:" .. self.registry_port .. "/enterprise-metrics-provisioner",
	}, {
		chdir = backend_enterprise_path,
	})
	shell.run({
		"docker",
		"push",
		"k3d-grafana:" .. self.registry_port .. "/enterprise-metrics-provisioner",
	}, {
		chdir = backend_enterprise_path,
	})
end

function K3d:build_gel_image(gel_path, force)
	local exists = shell.run_raw(
		"docker image ls | grep k3d-grafana:" .. self.registry_port .. "/enterprise-logs | grep latest"
	)
	if exists and not force then
		return
	end

	shell.run({
		"make",
		"enterprise-logs-image",
	}, {
		chdir = gel_path,
	})
	shell.run({
		"docker",
		"tag",
		"us.gcr.io/kubernetes-dev/enterprise-logs",
		"k3d-grafana:" .. self.registry_port .. "/enterprise-logs:latest",
	}, {
		chdir = gel_path,
	})
	shell.run({
		"docker",
		"push",
		"k3d-grafana:" .. self.registry_port .. "/enterprise-logs:latest",
	})
end

function K3d:build_loki_image(loki_path, force)
	local exists = shell.run_raw(
		"docker image ls | grep k3d-grafana:" .. self.registry_port .. "/loki | grep latest"
	)
	if exists and not force then
		return
	end

	shell.run({
		"make",
		"loki-image",
	}, {
		chdir = loki_path,
	})

  local image_tag_output = shell.run({
    "./tools/image-tag"
  }, {
		chdir = loki_path,
    capture = true
  })

  local image_tag = string.gsub(image_tag_output.output, "\n", "")

	shell.run({
		"docker",
		"tag",
		"grafana/loki:" .. image_tag,
		"k3d-grafana:" .. self.registry_port .. "/loki:latest",
	}, {
		chdir = loki_path,
	})

	shell.run({
		"docker",
		"push",
		"k3d-grafana:" .. self.registry_port .. "/loki:latest",
	})
end

function K3d:create_namespace()
	setContext(self.cluster)
	shell.run({
		"kubectl",
		"create",
		"namespace",
		self.namespace,
	})
end

function K3d:port_forward(service, ports)
	shell.run({
		"kubectl",
		"--namespace",
		self.namespace,
		"port-forward",
		service,
		ports,
	})
end

function K3d:create_license_secret(namespace, name, path)
	setContext(self.cluster)
	shell.run({
		"kubectl",
		"create",
		"secret",
		"generic",
		name,
		"--namespace",
		namespace,
		"--from-file",
		"license.jwt=" .. path,
	})
end

function k3d.new(cluster, namespace, nodes)
	local self = {
		cluster = cluster,
		namespace = namespace,
    nodes = nodes
	}
	setmetatable(self, { __index = K3d })
	return self
end

return k3d
