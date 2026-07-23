-- yaml_loader.lua
local yaml = require("tidal_snipgen.yaml")
local paths = require("tidal_snipgen.paths")

local M = {}

function M.load_dirt_samples()
	local yaml_files = {
		samps = paths.get_temp_dir() .. "dirt_samps.yaml",
		synths = paths.get_temp_dir() .. "dirt_synths.yaml",
		fx = paths.get_temp_dir() .. "dirt_fx.yaml",
	}

	local data = { samps = {}, synths = {}, fx = {} }

	for type, path in pairs(yaml_files) do
		local file = io.open(path, "r")
		if file then
			local content = file:read("*a")
			file:close()
			local success, parsed = pcall(yaml.eval, content)
			if success then
				data[type] = parsed
			else
				vim.notify("Failed to parse YAML: " .. path, vim.log.levels.ERROR)
			end
		else
			-- Create empty file if it doesn't exist
			file = io.open(path, "w")
			if file then
				file:write("---\n") -- Write empty YAML
				file:close()
				data[type] = {}
			else
				vim.notify("Could not create YAML file: " .. path, vim.log.levels.ERROR)
			end
		end
	end

	return data
end

return M
