local shell = require("shell-games")

--- @module tanka
local tanka = {}

-- class Tanka
local Tanka = {}

function Tanka:set_server_port(port)
	local _, err = shell.run({
		"tk",
		"env",
		"set",
		self.environment,
		"--server=https://0.0.0.0:" .. port,
	}, {
		chdir = self.ksonnet_path,
	})

	if err then
		print(err)
		os.exit(1)
	end
end

function Tanka:apply()
	local _, err = shell.run({
		"tk",
		"apply",
		self.environment,
		"--dangerous-auto-approve",
	}, {
		chdir = self.ksonnet_path,
	})

	if err then
		print(err)
		os.exit(1)
	end
end

function tanka.new(ksonnet_path, environment, port)
	local self = {
		ksonnet_path = ksonnet_path,
		environment = "environments/" .. environment,
	}
	setmetatable(self, { __index = Tanka })

	self:set_server_port(port)
	return self
end

return tanka
