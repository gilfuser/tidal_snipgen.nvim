local paths = require("tidal_snipgen.paths")
local yaml = require("tidal_snipgen.yaml") -- Your custom parser

local M = {}

function M.load_dirt_samples()
	local samples_dir = paths.resolve_samples_dir()
	local temp_dir = paths.get_temp_dir()
	local yaml_files = {
		samps = temp_dir .. "/dirt_samps.yaml",
		-- synths = temp_dir .. "/dirt_synths.yaml",
		-- fx = temp_dir .. "/dirt_fx.yaml",
	}

	local data = {}

	for type, path in pairs(yaml_files) do
		local file = io.open(path, "r")
		if file then
			local content = file:read("*a")
			file:close()
			data[type] = yaml.eval(content) or {}
		end
	end

	return {
		samples_dir = samples_dir,
		yaml_data = data,
		temp_dir = temp_dir,
	}
end

return M
