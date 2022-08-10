local shell = require("shell-games")
local Helm = {}

local function exec(command)
	local _, err = shell.run(command)
	if err then
		print(err)
		os.exit(1)
	end
end

function Helm.upgrade(namespace, deployment, chart, values)
	local command = {
		"helm",
		"upgrade",
		deployment,
		chart,
		"--install",
		"--create-namespace",
		"--namespace",
		namespace,
		"-f",
		values,
	}

	print(table.concat(command, " "))
	exec(command)
end

function Helm.update(chart)
	shell.run({ "helm", "dependency", "update", chart })
end

return Helm
