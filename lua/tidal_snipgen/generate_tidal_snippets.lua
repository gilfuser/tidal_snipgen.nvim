--  ~/.config/nvim/lua/plugins/generate_tidal_snippets.lua
local parser = require("tidal_snipgen.parser")
local io = require("io")
local trigger_utils = require("tidal_snipgen.trigger_utils")

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
	local snippets = {}
	table.insert(snippets, 'local ls = require("luasnip")')
	table.insert(snippets, "local s = ls.snippet")
	table.insert(snippets, "local t = ls.text_node")
	table.insert(snippets, "")
	table.insert(snippets, "-- Define your Tidal Cycles snippets here")
	table.insert(snippets, 'ls.add_snippets("tidal", {')

	local existing_triggers = {}
	local existing_prefixes = classify_sound_banks(data)
	local existing_suffixes = classify_sample_names(data, existing_prefixes)

	-- Generate snippets
	for sound_bank, attributes in pairs(data) do
		local is_drummachine = attributes.drummachine or false
		local prefix = existing_prefixes[sound_bank]

		for sample_name, sample_attributes in pairs(attributes) do
			-- Skip non-sample attributes like `drummachine`
			if type(sample_attributes) == "table" and sample_name ~= "drummachine" then
				local suffix = existing_suffixes[sample_name]
				local trigger = trigger_utils.generate_unique_trigger(existing_triggers, prefix, suffix)
				existing_triggers[trigger] = true

				-- Ensure variations is not nil
				if sample_attributes.variations == nil then
					error(
						"Error: 'variations' attribute is nil for sample '"
							.. sample_name
							.. "'. Please check the .yaml file."
					)
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
			end
		end
	end

	table.insert(snippets, "})")

	return table.concat(snippets, "\n")
end

-- Main function to parse YAML and generate snippets
local function main()
	local yaml_file_path = vim.fn.expand("~/Samples/dirt_samps.yaml")
	local output_file_path = vim.fn.expand("~/.config/nvim/luasnippets/snipgen_tidal.lua")

	local data, err = parser.parse_yaml(yaml_file_path)
	if not data then
		error("Error parsing YAML file: " .. err)
	end

	local snippets = generate_snippets(data)

	local file = io.open(output_file_path, "w")
	if not file then
		error("Cannot open file for writing: " .. output_file_path)
	end

	file:write(snippets)
	file:close()

	print("Snippets generated and written to " .. output_file_path)
end

main()
