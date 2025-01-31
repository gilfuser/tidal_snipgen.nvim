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

	-- Add path normalization after parsing
	for bank_name, bank_data in pairs(data) do
		for sample_name, sample_info in pairs(bank_data) do
			if type(sample_name) == "string" then
				-- Normalize Windows paths
				local normalized = sample_name:gsub("\\", "/")
				if normalized ~= sample_name then
					bank_data[normalized] = bank_data[sample_name]
					bank_data[sample_name] = nil
				end
			end
		end
	end

	return data
end
