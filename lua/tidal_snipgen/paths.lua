local M = {}

function M.get_home()
	return vim.loop.os_homedir()
end

function M.get_temp_dir()
	local sep = package.config:sub(1, 1)
	return M.get_home() .. sep .. ".tidal_snipgen"
end

function M.get_samples_path()
	local temp_dir = M.get_temp_dir()
	local yaml_path = temp_dir .. package.config:sub(1, 1) .. "samples_path.yaml"

	local file = io.open(yaml_path, "r")
	if not file then
		return nil
	end

	local content = file:read("*a")
	file:close()

	-- Simple YAML parsing for this specific file format
	local user_path = content:match("user_defined:%s*(.-)\n")
	return user_path and vim.fn.expand(user_path) or nil
end

function M.get_platform_default()
	if vim.fn.has("macunix") == 1 then
		return M.get_home() .. "/Library/Application Support/SuperCollider/downloaded_quarks/Dirt-Samples"
	elseif vim.fn.has("win32") == 1 then
		return M.get_home() .. "\\AppData\\Local\\SuperCollider\\downloaded-quarks\\Dirt-Samples"
	else
		return M.get_home() .. "/.local/share/SuperCollider/downloaded_quarks/Dirt-Samples"
	end
end

function M.resolve_samples_dir()
	return M.get_samples_path() or M.get_platform_default()
end

return M
