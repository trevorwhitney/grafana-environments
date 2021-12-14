local shell = require("shell-games")

--- @module tanka
local tanka = {}

-- class Tanka
local Tanka = {}

function Tanka:set_server_port(port, env)
	local _, err = shell.run({
		"tk",
		"env",
		"set",
		env,
		"--server=https://0.0.0.0:" .. port,
	}, {
		chdir = self.ksonnet_path,
	})

	if err then
		print(err)
		os.exit(1)
	end
end

function Tanka:apply(env)
	local _, err = shell.run({
		"tk",
		"apply",
		env,
    "--dangerous-auto-approve"
	}, {
		chdir = self.ksonnet_path,
	})

	if err then
		print(err)
		os.exit(1)
	end
end

function tanka.new(ksonnet_path)
	local self = {
		ksonnet_path = ksonnet_path,
	}
	setmetatable(self, { __index = Tanka })
	return self
end

return tanka
