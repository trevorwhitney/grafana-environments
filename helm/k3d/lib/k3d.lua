local K3d = {}

local function prepareRegistry()
	local registryExists = os.execute("k3d registry list | grep k3d-grafana")
	if not registryExists then
		os.execute("k3d registry create grafana")
	end
end

local function prepareCluster(cluster)
	local clusterExists = os.execute("k3d cluster list | grep " .. cluster)
	if not clusterExists then
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

function K3d.prepare(cluster)
	prepareRegistry()
	prepareCluster(cluster)
end

return K3d
