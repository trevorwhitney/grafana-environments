local Helm = {}

local function get_pods(namespace)
	local result = io.popen("kubectl -n " .. namespace .. " get pods", "r")
	local pods = -1 -- start at -1 to account for header

	for _ in result:lines() do
		pods = pods + 1
	end

	return pods
end

local function exec(command)
	local success, _, signal = os.execute(command)
  if not success then
    os.exit(signal)
  end
end

local function helm(command, namespace, deployment, chart, values)
	return "helm " .. command .. " -n " .. namespace .. " " .. deployment .. " " .. chart .. " -f " .. values
end

local function install(namespace, deployment, chart, values)
	local command = helm("install", namespace, deployment, chart, values) .. " --create-namespace"
	print("running: " .. command)
	exec(command)
end

local function upgrade(namespace, deployment, chart, values)
	local command = helm("upgrade", namespace, deployment, chart, values)
	print("running: " .. command)
	exec(command)
end

function Helm.cwd()
	local result = io.popen("cd $(dirname " .. arg[0] .. ") && pwd", "r")
	local lastline

	for line in result:lines() do
		lastline = line
	end

	return lastline
end

function Helm.upgradeOrInstall(count, namespace, deployment, chart, values)
	local pods = get_pods(namespace)
	if pods < count then
		install(namespace, deployment, chart, values)
	else
		upgrade(namespace, deployment, chart, values)
	end
end

return Helm
