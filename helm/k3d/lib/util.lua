local M = {}

function M.cwd()
	local result = io.popen("cd $(dirname " .. arg[0] .. ") && pwd", "r")
	local lastline

	for line in result:lines() do
		lastline = line
	end

	return lastline
end

return M
