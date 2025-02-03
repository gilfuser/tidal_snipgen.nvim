-- generate.lua
local config = require("tidal_snipgen.config")
local io = require("io")
local trigger_utils = require("tidal_snipgen.trigger_utils")
local dirmanager = require("tidal_snipgen.dir_manager")
local paths = require("tidal_snipgen.paths")
local parser = require("tidal_snipgen.parser") -- Ensure parser is required here

-- Function to classify sound banks and generate unique prefixes
local function classify_sound_banks(data)
	local existing_prefixes = {}
	local sound_bank_groups = {}

	-- First pass: Group sound banks by their first three characters
	for sound_bank, attributes in pairs(data) do
		local prefix = trigger_utils.shorten_key(sound_bank)
		if not sound_bank_groups[prefix] then
			sound_bank_groups[prefix] = {}
		end
		table.insert(sound_bank_groups[prefix], sound_bank)
	end

	-- Second pass: Generate unique prefixes for each group
	for prefix, sound_banks in pairs(sound_bank_groups) do
		if #sound_banks == 1 then
			-- Unique prefix
			existing_prefixes[sound_banks[1]] = prefix
		else
			-- Non-unique prefix, recursively compare
			for _, sound_bank in ipairs(sound_banks) do
				existing_prefixes[sound_bank] = trigger_utils.generate_unique_prefix(existing_prefixes, sound_bank)
			end
		end
	end

	return existing_prefixes
end

-- Function to classify sample names and generate unique suffixes
local function classify_sample_names(data, existing_prefixes)
	local existing_suffixes = {}
	local sample_name_groups = {}

	-- First pass: Group sample names by their sound bank prefix and suffix
	for sound_bank, attributes in pairs(data) do
		local prefix = existing_prefixes[sound_bank]
		for sample_name, _ in pairs(attributes) do
			-- Skip non-sample attributes like `drummachine`
			if type(sample_name) == "string" and sample_name ~= "drummachine" then
				local suffix = sample_name:match("-(%w+)$") or sample_name:sub(1, 3)
				local group_key = prefix .. suffix
				if not sample_name_groups[group_key] then
					sample_name_groups[group_key] = {}
				end
				table.insert(sample_name_groups[group_key], sample_name)
			end
		end
	end

	-- Second pass: Generate unique suffixes for each group
	for group_key, sample_names in pairs(sample_name_groups) do
		if #sample_names == 1 then
			-- Unique suffix
			local suffix_length = #(sample_names[1]:match("-(%w+)$") or sample_names[1]:sub(1, 3))
			existing_suffixes[sample_names[1]] = group_key:sub(-suffix_length)
		else
			-- Non-unique suffix, recursively compare
			for _, sample_name in ipairs(sample_names) do
				existing_suffixes[sample_name] = trigger_utils.generate_unique_suffix(existing_suffixes, sample_name)
			end
		end
	end

	return existing_suffixes
end

-- Function to generate LuaSnip snippets
local function generate_snippets(data)
	local timestamp = os.date("generated in %Y-%m-%d, at %H:%M:%S")
	local snippets = {}
	table.insert(snippets, 'local ls = require("luasnip")')
	table.insert(snippets, "local s = ls.snippet")
	table.insert(snippets, "local t = ls.text_node")
	table.insert(snippets, "")
	table.insert(snippets, "-- " .. timestamp)
	table.insert(snippets, 'ls.add_snippets("tidal", {')

	local existing_triggers = {}
	local existing_prefixes = classify_sound_banks(data)
	local existing_suffixes = classify_sample_names(data, existing_prefixes)

	-- Check if there is only one sound bank
	local single_sound_bank = nil
	if #vim.tbl_keys(data) == 1 then
		for k in pairs(data) do
			single_sound_bank = k
		end
	end

	-- Generate snippets
	for sound_bank, attributes in pairs(data) do
		local is_drummachine = attributes.drummachine or false
		local prefix = single_sound_bank and "" or existing_prefixes[sound_bank]

		for sample_name, sample_attributes in pairs(attributes) do
			-- Skip non-sample attributes like `drummachine`
			if type(sample_attributes) == "table" and sample_name ~= "drummachine" then
				local suffix = existing_suffixes[sample_name]
				local trigger = trigger_utils.generate_unique_trigger(existing_triggers, prefix, suffix)
				existing_triggers[trigger] = true

				-- Ensure variations is not nil
				if sample_attributes.variations == nil then
					vim.notify("Skipping sample with missing variations: " .. sample_name, vim.log.levels.WARN)
					goto continue -- Skip only this iteration
				end

				local description = sound_bank .. " " .. sample_attributes.variations
				if is_drummachine then
					description = description .. " dm"
				else
					if sample_attributes.is_shorter then
						description = description .. " shorter"
					elseif sample_attributes.is_short then
						description = description .. " short"
					elseif sample_attributes.is_long then
						description = description .. " long"
					elseif sample_attributes.is_longer then
						description = description .. " longer"
					end
				end
				table.insert(
					snippets,
					string.format(
						'    s({ trig = "%s", snippetType = "autosnippet", name = "%s/%s", dscr = "%s" }, { t("%s ") }),',
						trigger,
						sound_bank,
						sample_name,
						description,
						sample_name
					)
				)
				::continue::
			end
		end
	end

	table.insert(snippets, "})")

	return table.concat(snippets, "\n")
end

-- Main function to parse YAML and generate snippets
local M = {
	generate = function()
		local yaml_paths = {
			samps = paths.get_temp_dir() .. package.config:sub(1, 1) .. "dirt_samps.yaml",
		}

		local data, err = parser.parse_yaml(yaml_paths.samps)
		if not data then
			vim.notify("Failed to load sample data: " .. tostring(err), vim.log.levels.ERROR)
			return
		end

		-- Generate snippets
		local snippets = generate_snippets(data)

		-- Ensure the output directory exists
		local output_file = config.user_config.output_path
		local assets_dir = vim.fn.fnamemodify(output_file, ":h")

		-- Ensure the directory exists
		if vim.fn.isdirectory(assets_dir) == 0 then
			vim.fn.mkdir(assets_dir, "p")
		end

		-- Write to the output file
		local file = io.open(output_file, "w")
		if file then
			file:write(snippets)
			file:close()
			vim.notify("Snippets generated: " .. output_file)
		else
			vim.notify("Failed to write snippets to: " .. output_file, vim.log.levels.ERROR)
		end
	end,
}
return M
