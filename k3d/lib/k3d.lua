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

local function prepareCluster(cluster)
	local _, err = shell.run_raw("k3d cluster list | grep " .. cluster)
	if err then
		os.execute(
			"k3d cluster create "
				.. cluster
				.. " --registry-use k3d-grafana:45629"
				.. " --volume "
				.. os.getenv("HOME")
				.. "/.var/lib/rancher/k3d/storage:/var/lib/rancher/k3s/storage"
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

function K3d:prepare()
	prepareRegistry()
	prepareCluster(self.cluster)
	setContext(self.cluster)
end

function K3d:create_namespace(namespace)
	setContext(self.cluster)
	shell.run({
		"kubectl",
		"create",
		"namespace",
		namespace,
	})
end

function k3d.new(cluster)
	local self = {
		cluster = cluster
	}
	setmetatable(self, { __index = K3d })
	return self
end

return k3d
