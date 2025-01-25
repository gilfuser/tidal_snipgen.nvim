-- ~/.config/nvim/lua/plugins/tidal_snipgen/parser.lua

-- Ensure LuaRocks paths are included
local function add_luarocks_path()
	local package_path_str =
		vim.fn.expand("~/.luarocks/share/lua/5.4/?.lua;/home/skmecs/.luarocks/share/lua/5.4/?/init.lua;")
	local install_cpath_pattern = vim.fn.expand("~/.luarocks/lib/lua/5.4/?.so;")

	if not string.find(package.path, package_path_str, 1, true) then
		package.path = package.path .. ";" .. package_path_str
	end

	if not string.find(package.cpath, install_cpath_pattern, 1, true) then
		package.cpath = package.cpath .. ";" .. install_cpath_pattern
	end
end

add_luarocks_path()

local yaml = require("yaml")

local M = {}

function M.parse_yaml(file_path)
	local file = io.open(file_path, "r")
	if not file then
		return nil, "Cannot open file: " .. file_path
	end

	local content = file:read("*all")
	file:close()

	local data, err = yaml.eval(content)
	if err then
		return nil, "YAML Parsing Error: " .. err
	end

	return data
end

return M
