local Helm = {}

local function exec(command)
	local success, _, signal = os.execute(command)
	if not success then
		os.exit(signal)
	end
end

local function upgrade(namespace, deployment, chart, values)
	local command = "helm upgrade --install"
		.. " -n "
		.. namespace
		.. " "
		.. deployment
		.. " "
		.. chart
		.. " -f "
		.. values
	print("running: " .. command)
	exec(command)
end

function Helm.upgrade(namespace, deployment, chart, values)
	upgrade(namespace, deployment, chart, values)
end

return Helm
