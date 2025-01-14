local M = {}

function M.shorten_key(key)
	return key:sub(1, 3)
end

function M.generate_unique_trigger(existing_triggers, base_trigger)
	local trigger = base_trigger
	local suffix = 1
	while existing_triggers[trigger] do
		trigger = base_trigger .. tostring(suffix)
		suffix = suffix + 1
	end
	return trigger
end

return M
