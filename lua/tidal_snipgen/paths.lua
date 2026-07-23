-- paths.lua
local M = {}

-- Get platform-specific path separator
function M.get_sep()
	return package.config:sub(1, 1)
end

-- Get home directory (cross-platform)
function M.get_home()
	return vim.loop.os_homedir()
end

-- Get temp directory with trailing separator
function M.get_temp_dir()
	local sep = M.get_sep()
	local dir = M.get_home() .. sep .. ".tidal_snipgen"
	-- Ensure trailing separator
	if dir:sub(-1) ~= sep then
		dir = dir .. sep
	end
	return dir
end

-- Read samples path from YAML
function M.get_samples_path()
	local yaml_path = M.get_temp_dir() .. "samples_path.yaml"
	local file = io.open(yaml_path, "r")
	if not file then
		return nil
	end

	local content = file:read("*a")
	file:close()

	-- Simple YAML parsing for this specific format
	local user_path = content:match("user_defined:%s*(.-)\n")
	return user_path and vim.fn.expand(user_path) or nil
end

-- Get platform-specific default samples path
function M.get_platform_default()
	local sep = M.get_sep()
	if vim.fn.has("macunix") == 1 then
		return M.get_home()
			.. sep
			.. "Library"
			.. sep
			.. "Application Support"
			.. sep
			.. "SuperCollider"
			.. sep
			.. "downloaded-quarks"
			.. sep
			.. "Dirt-Samples"
	elseif vim.fn.has("win32") == 1 then
		return M.get_home()
			.. sep
			.. "AppData"
			.. sep
			.. "Local"
			.. sep
			.. "SuperCollider"
			.. sep
			.. "downloaded-quarks"
			.. sep
			.. "Dirt-Samples"
	else
		return M.get_home()
			.. sep
			.. ".local"
			.. sep
			.. "share"
			.. sep
			.. "SuperCollider"
			.. sep
			.. "downloaded-quarks"
			.. sep
			.. "Dirt-Samples"
	end
end

-- Resolve samples directory (user-defined or default)
function M.resolve_samples_dir()
	return M.get_samples_path() or M.get_platform_default()
end

-- Cross-platform path joining
function M.join(...)
	local sep = M.get_sep()
	local parts = { ... }
	-- Remove empty parts and normalize separators
	for i, part in ipairs(parts) do
		parts[i] = part:gsub("[/\\]", sep):gsub(sep .. "+$", "")
	end
	return table.concat(parts, sep)
end

-- Expand a given path, handling ~ for home directory
function M.expand_path(path)
	local sep = M.get_sep()
	local home = M.get_home()
	return path:gsub("^~", home):gsub("/", sep)
end

return M
