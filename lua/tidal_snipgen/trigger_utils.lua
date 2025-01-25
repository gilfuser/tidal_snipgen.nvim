local M = {}

-- Function to shorten the key to the first three characters
function M.shorten_key(key)
	return key:sub(1, 3)
end

-- Function to find the first differing character between two strings starting from a given position
local function find_first_differing_char(str1, str2, start_pos)
	if type(str2) ~= "string" then
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
function M.generate_unique_prefix(existing_prefixes, sound_bank, sound_banks)
	local base_prefix = M.shorten_key(sound_bank)
	local prefix = base_prefix

	-- Check if the base prefix is unique
	if not existing_prefixes[prefix] then
		return prefix
	end

	-- If not unique, find the next unique character
	local suffix = 1
	local unique = false

	while not unique do
		-- Find the first differing character after the base prefix
		local next_char = find_first_differing_char(sound_bank, existing_prefixes[prefix], 3 + suffix)
			or tostring(suffix)
		prefix = base_prefix .. next_char
		suffix = suffix + 1

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
		return suffix
	end

	-- If not unique, find the next unique character
	local suffix_num = 1
	local unique = false

	while not unique do
		-- Find the first differing character after the base suffix
		local next_char = find_first_differing_char(sample_name, existing_suffixes[suffix], 3 + suffix_num)
			or tostring(suffix_num)
		suffix = base_suffix .. next_char
		suffix_num = suffix_num + 1

		if not existing_suffixes[suffix] then
			unique = true
		end
	end

	return suffix
end

-- Function to generate unique triggers based on the ruleset
function M.generate_unique_trigger(existing_triggers, prefix, suffix)
	local trigger = prefix .. suffix

	-- Check if the base trigger is unique
	if not existing_triggers[trigger] then
		return trigger
	end

	-- If not unique, find the next unique character
	local suffix_num = 1
	local unique = false

	while not unique do
		local next_char = tostring(suffix_num)
		trigger = prefix .. next_char
		suffix_num = suffix_num + 1

		if not existing_triggers[trigger] then
			unique = true
		end
	end

	return trigger
end

return M
