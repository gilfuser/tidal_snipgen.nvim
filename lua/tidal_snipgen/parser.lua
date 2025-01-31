local yaml = require("tidal_snipgen.yaml")

local function validate_structure(data)
	if type(data) ~= "table" then
		return false, "Invalid YAML structure: root must be a table"
	end

	for bank, attrs in pairs(data) do
		if type(attrs) ~= "table" then
			return false, "Invalid bank structure: " .. bank
		end
	end

	return true
end

local M = {}

function M.parse_yaml(file_path)
	local file = io.open(file_path, "r")
	if not file then
		return nil, "Cannot open file: " .. file_path
	end

	local content = file:read("*all")
	file:close()

	local success, data = pcall(yaml.eval, content)
	if not success then
		return nil, "YAML Parsing Error: " .. data
	end

	local valid, err = validate_structure(data)
	if not valid then
		return nil, err
	end

	return data
end
