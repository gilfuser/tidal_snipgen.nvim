-- ui.lua
local trigger_utils = require("tidal_snipgen.trigger_utils")
local fzf_lua = require("fzf-lua")
local fzf_actions = require("fzf-lua.actions")
local process = require("tidal_snipgen.process")
local loader = require("tidal_snipgen.yaml_loader")

local M = {}

local function display_samples(data, sound_bank)
	local bank_data = data[sound_bank]
	if not bank_data then
		vim.notify("No samples found for sound bank: " .. sound_bank, vim.log.levels.ERROR)
		return
	end

	local sample_list = {}
	local is_drummachine = bank_data.drummachine

	for sample_name, attributes in pairs(bank_data) do
		if type(attributes) == "table" then
			local info = sample_name .. ": "
			if not is_drummachine then
				if attributes.is_long then
					info = info .. "long "
				end
				if attributes.is_longer then
					info = info .. "longer "
				end
				if attributes.is_short then
					info = info .. "short "
				end
				if attributes.is_shorter then
					info = info .. "shorter "
				end
			end
			info = info .. tostring(attributes.variations or 0)
			table.insert(sample_list, info)
		end
	end

	table.sort(sample_list)

	fzf_lua.fzf_exec(sample_list, {
		prompt = "Samples> ",
		actions = {
			["default"] = function(selected)
				-- Extract the sample name up to the colon and add a space
				local sample_name = selected[1]:match("^(%S+):")
				if sample_name then
					vim.api.nvim_put({ sample_name .. " " }, "c", true, true)
				end
			end,
			["ctrl-h"] = function()
				M.show_sound_banks(nil, data) -- Go back to sound banks
			end,
			["esc"] = fzf_actions.close, -- Close the FZF window
		},
		winopts = {
			height = 0.9, -- Make it taller
			width = 0.2, -- Make it thinner
			row = 0.1, -- Align to the top
			col = 1, -- Align to the right
			border = "rounded",
		},
	})
end

function M.show_sound_banks()
	local data = loader.load_dirt_samples()
	-- Check GHCI dependency only if necessary, not during UI display
	if not data then
		local errors = process.check_dependencies()
		if #errors > 0 then
			vim.notify("Prerequisites missing:\n- " .. table.concat(errors, "\n- "), vim.log.levels.ERROR)
			return
		end
	end

	if not data or not data.samps or vim.tbl_isempty(data.samps) then
		vim.notify(
			"No sound banks found. Check:\n1. SuperDirt is initialized\n2. Samples are loaded",
			vim.log.levels.ERROR
		)
		return
	end

	-- Check if there is only one sound bank
	if #vim.tbl_keys(data.samps) == 1 then
		for sound_bank in pairs(data.samps) do
			display_samples(data.samps, sound_bank)
		end
		return
	end

	-- Use only the samps data
	local sound_banks = {}
	local existing_prefixes = {}

	for sound_bank, attributes in pairs(data.samps) do
		local prefix = trigger_utils.generate_unique_prefix(existing_prefixes, sound_bank)
		existing_prefixes[prefix] = sound_bank

		local display_name = prefix .. " -> " .. sound_bank
		if attributes.drummachine then
			display_name = display_name .. " _ dm"
		end

		table.insert(sound_banks, display_name)
	end

	-- Sort and display
	table.sort(sound_banks)

	fzf_lua.fzf_exec(sound_banks, {
		prompt = "Sound Banks> ",
		actions = {
			["default"] = function(selected)
				local sound_bank = selected[1]:match("-> (%S+)")
				if sound_bank then
					display_samples(data.samps, sound_bank) -- Pass samps data
				else
					vim.notify("Invalid selection", vim.log.levels.ERROR)
				end
			end,
			["ctrl-l"] = function(selected)
				local sound_bank = selected[1]:match("-> (%S+)")
				if sound_bank then
					display_samples(data.samps, sound_bank) -- Pass samps data
				else
					vim.notify("Invalid selection", vim.log.levels.ERROR)
				end
			end,
			["esc"] = fzf_actions.close,
		},
		winopts = {
			height = 0.9,
			width = 0.2,
			row = 0.1,
			col = 1,
			border = "rounded",
		},
	})
end

return M
