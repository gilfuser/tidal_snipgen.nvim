local M = {}

-- Function to shorten the key to the first three characters
function M.shorten_key(key)
	return key:sub(1, 3)
end

-- Function to find the first differing character between two strings starting from a given position
local function find_first_differing_char(str1, str2, start_pos)
	if type(str1) ~= "string" or type(str2) ~= "string" then
		return nil
	end
	for i = start_pos, math.min(#str1, #str2) do
		if str1:sub(i, i) ~= str2:sub(i, i) then
			return str1:sub(i, i)
		end
	end
	return nil
end

-- Function to generate unique prefixes based on the ruleset
function M.generate_unique_prefix(existing_prefixes, sound_bank)
	local base_prefix = M.shorten_key(sound_bank)
	local prefix = base_prefix

	-- Check if the base prefix is unique
	if not existing_prefixes[prefix] then
		return prefix
	end

	-- If not unique, find the next unique character recursively
	local unique = false
	local suffix_index = 4

	while not unique do
		local next_char = find_first_differing_char(sound_bank, existing_prefixes[prefix], suffix_index)
		if next_char then
			prefix = base_prefix .. next_char
		else
			-- If no differing character found, use the next character in the sound_bank
			prefix = sound_bank:sub(1, suffix_index)
		end
		suffix_index = suffix_index + 1

		if not existing_prefixes[prefix] then
			unique = true
		end
	end

	return prefix
end

-- Function to generate unique suffixes based on the ruleset
function M.generate_unique_suffix(existing_suffixes, sample_name, sample_names)
	local base_suffix = sample_name:match("-(%w+)$") or sample_name:sub(1, 3)
	local suffix = base_suffix

	-- Check if the base suffix is unique
	if not existing_suffixes[suffix] then
		existing_suffixes[suffix] = sample_name
		return suffix
	end

	-- If not unique, find the next unique character recursively
	local unique = false
	local suffix_index = 4

	while not unique do
		for existing, name in pairs(existing_suffixes) do
			if name == sample_name then
				return existing
			end
		end

		local next_char = find_first_differing_char(sample_name, existing_suffixes[suffix], suffix_index)
		if next_char then
			suffix = base_suffix .. next_char
		else
			-- If no differing character found, use the next character in the sample_name
			suffix = sample_name:sub(1, suffix_index)
		end
		suffix_index = suffix_index + 1

		if not existing_suffixes[suffix] then
			unique = true
		end
	end

	existing_suffixes[suffix] = sample_name
	return suffix
end

-- Function to generate unique triggers based on the ruleset
function M.generate_unique_trigger(existing_triggers, prefix, suffix)
	local trigger = prefix .. suffix

	-- Check if the base trigger is unique
	if not existing_triggers[trigger] then
		existing_triggers[trigger] = true
		return trigger
	end

	-- If not unique, find the next unique character recursively
	local unique = false
	local suffix_index = 1

	while not unique do
		local next_char = tostring(suffix_index)
		trigger = prefix .. next_char
		suffix_index = suffix_index + 1

		if not existing_triggers[trigger] then
			unique = true
		end
	end

	existing_triggers[trigger] = true
	return trigger
end

return M
