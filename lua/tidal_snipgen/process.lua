-- process.lua
local M = {}

function M.is_process_running(name)
	if package.config:sub(1, 1) == "\\" then -- Windows
		local handle = io.popen('tasklist /FI "IMAGENAME eq ' .. name .. '.exe" 2>nul')
		local result = handle:read("*a")
		handle:close()
		print("Tasklist result for " .. name .. ": " .. result) -- Debug log
		return result:find(name) ~= nil
	else -- Unix-like
		local handle = io.popen("pgrep -x " .. name)
		local result = handle:read("*a")
		handle:close()
		print("Pgrep result for " .. name .. ": " .. result) -- Debug log
		return result ~= ""
	end
end

function M.check_dependencies()
	local status = {
		supercollider = M.is_process_running("sclang"),
		ghci = M.is_process_running("ghc"),
	}

	-- Debug logs
	print("SuperCollider running: " .. tostring(status.supercollider))
	print("GHCI running: " .. tostring(status.ghci))

	if not status.supercollider then
		vim.notify("SuperCollider (sclang) not detected", vim.log.levels.WARN)
	end

	if not status.ghci then
		vim.notify("GHCI not detected", vim.log.levels.WARN)
	end

	return status
end

return M
