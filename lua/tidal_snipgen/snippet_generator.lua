local parser = require("tidal_snipgen.parser")

local M = {}

local function shorten_key(key)
	return key:sub(1, 3)
end

local function generate_unique_trigger(existing_triggers, base_trigger)
	local trigger = base_trigger
	local suffix = 1
	while existing_triggers[trigger] do
		trigger = base_trigger .. tostring(suffix)
		suffix = suffix + 1
	end
	return trigger
end

local function file_modified_time(file_path)
	local file = io.popen("stat -c %Y " .. file_path)
	local last_modified = file:read("*n")
	file:close()
	return last_modified
end

function M.generate_snippets(yaml_file_path, snippets_file_path)
	-- Parse YAML file
	local data, err = parser.parse_yaml(yaml_file_path)
	if not data then
		print("Error parsing YAML file: " .. err)
		return
	end

	-- Generate snippets
	local snippets = {}
	local existing_triggers = {}

	for sound_bank, samples in pairs(data) do
		for sample_name, attributes in pairs(samples) do
			local combined_trigger =
				generate_unique_trigger(existing_triggers, shorten_key(sound_bank) .. shorten_key(sample_name))
			existing_triggers[combined_trigger] = true

			-- Ensure 'variations' attribute is present and is a number
			local num_variations = attributes.variations
			if type(num_variations) ~= "number" then
				print(
					string.format(
						"Warning: 'variations' attribute missing or invalid for sample '%s' in sound bank '%s'",
						sample_name,
						sound_bank
					)
				)
				num_variations = 0 -- Default to 0 or any other sensible default
			end

			local snippet = {
				prefix = combined_trigger,
				body = string.format("%s", sample_name),
				description = string.format("%s, %s, %d", sound_bank, sample_name, num_variations),
				scope = "haskell,tidal",
			}
			snippets[string.format("%s/%s", sound_bank, sample_name)] = snippet
		end
	end

	-- Write snippets to file
	local file = io.open(snippets_file_path, "w")
	if not file then
		print("Error opening file for writing: " .. snippets_file_path)
		return
	end

	file:write(vim.fn.json_encode(snippets))
	file:close()

	-- Set buffer filetype to JSON and format the file
	vim.cmd("e " .. snippets_file_path)
	vim.cmd("set filetype=json")
	if vim.fn.exists(":JsonFormatFile") == 2 then
		vim.cmd("JsonFormatFile")
	else
		print("JsonFormatFile command not found. Ensure json-nvim plugin is installed and loaded.")
	end
	vim.cmd("w")
end

function M.check_and_generate_snippets(yaml_file_path, snippets_file_path)
	local last_modified_yaml = file_modified_time(yaml_file_path)
	local last_modified_snippets = file_modified_time(snippets_file_path)

	if last_modified_yaml > last_modified_snippets then
		M.generate_snippets(yaml_file_path, snippets_file_path)
	else
		print("No changes detected in the YAML file.")
	end
end

return M
