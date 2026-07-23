local paths = require("tidal_snipgen.paths")

local M = {}

function M.normalize_path(path)
	return path:gsub("\\", "/")
end

function M.normalize_path(path)
	return path:gsub("\\", "/")
end

function M.ensure_temp_dir()
	local temp_dir = paths.get_temp_dir()
	vim.fn.mkdir(temp_dir, "p", 0755)
end

function M.write_samples_path(custom_path)
	M.ensure_temp_dir()
	local yaml_path = paths.get_temp_dir() .. "/samples_path.yaml"
	local content = string.format("---\nuser_defined: %s", custom_path)

	local file = io.open(yaml_path, "w")
	if file then
		file:write(content)
		file:close()
		return true
	end
	return false
end

return M
