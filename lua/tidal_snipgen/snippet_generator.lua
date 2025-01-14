local parser = require("tidal_snipgen.parser")
local trigger_utils = require("tidal_snipgen.trigger_utils")

local M = {}

function M.generate_snippets(yaml_file_path, snippets_file_path)
	-- Parse YAML file
	local data, err = parser.parse_yaml(yaml_file_path)
	if not data then
		print("Error parsing YAML file: " .. err)
		return
	end

	local snippets = {}
	local existing_triggers = {}

	for sound_bank, samples in pairs(data) do
		for sample_name, attributes in pairs(samples) do
			local base_trigger = trigger_utils.shorten_key(sound_bank) .. trigger_utils.shorten_key(sample_name)
			local combined_trigger = trigger_utils.generate_unique_trigger(existing_triggers, base_trigger)
			existing_triggers[combined_trigger] = true

			-- Ensure 'variations' attribute is present and is a number
			local num_variations = attributes.variations or 0

			snippets[combined_trigger] = {
				description = string.format(
					"Sound bank: %s, Sample: %s, Variations: %d",
					sound_bank,
					sample_name,
					num_variations
				),
				body = { string.format("%s[%d]", sample_name, num_variations) },
				scope = "haskell,tidal",
				prefix = { combined_trigger },
			}
		end
	end

	-- Write snippets to file
	local file = io.open(snippets_file_path, "w")
	if not file then
		print("Error writing to file: " .. snippets_file_path)
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

return M
