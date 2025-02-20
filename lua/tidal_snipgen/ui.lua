-- ui.lua
local loader = require("tidal_snipgen.yaml_loader")
local fzf_lua = require("fzf-lua")
local M = {}

local UI_CONFIG = {
	banks = {
		prompt = "Sound Banks> ",
		width = 0.4,
		formatter = function(bank, attrs)
			return string.format("%-25s %s", bank, attrs.drummachine and "⚡" or "")
		end,
	},
	samples = {
		prompt = "Samples> ",
		width = 0.5,
		formatter = function(sample, attrs)
			return string.format("%-25s (%3d)", sample, attrs.variations or 0)
		end,
	},
	variations = {
		prompt = "Variations> ",
		width = 0.3,
		formatter = function(var)
			return string.format("Variation %02d", var)
		end,
	},
}

local current_context = {
	bank = nil,
	sample = nil,
	data = nil,
	pattern_name = nil,
}

local function safe_fzf_exec(items, opts)
	local items_map = {}
	local items_str = {}

	for _, item in ipairs(items) do
		if item.text and item.value then
			table.insert(items_str, item.text)
			items_map[item.text] = {
				value = item.value,
				attrs = item.attrs,
			}
		end
	end

	if #items_str == 0 then
		return
	end

	fzf_lua.fzf_exec(
		items_str,
		vim.tbl_extend("force", {
			actions = {
				["default"] = function(selected)
					if opts.default_action and #selected > 0 then
						local data = items_map[selected[1]]
						opts.default_action(data.value, data.attrs)
					end
				end,
				["ctrl-s"] = function(selected)
					if opts.play_action and #selected > 0 then
						local data = items_map[selected[1]]
						opts.play_action(data.value, data.attrs)
					end
					return false -- Keep window open
				end,
				["ctrl-l"] = function(selected)
					if opts.nav_action and #selected > 0 then
						local data = items_map[selected[1]]
						opts.nav_action(data.value, data.attrs)
					end
					return false -- Keep window open
				end,
				["ctrl-h"] = function()
					if opts.back_action then
						opts.back_action()
					end
					return false -- Keep window open
				end,
			},
			winopts = {
				col = 1, -- Right-aligned
				border = "rounded",
			},
		}, opts or {})
	)
end

local function create_items(data, formatter)
	local items = {}
	for key, attrs in pairs(data) do
		if type(attrs) == "table" then
			table.insert(items, {
				text = formatter(key, attrs),
				value = key,
				attrs = attrs,
			})
		end
	end
	table.sort(items, function(a, b)
		return a.value < b.value
	end)
	return items
end

local function tidal_send(cmd)
	vim.schedule(function()
		vim.cmd("TidalSend1 " .. vim.api.nvim_replace_termcodes(cmd, true, true, true))
	end)
end

local function silence_sample()
	if current_context.pattern_name then
		tidal_send('p "' .. current_context.pattern_name .. '" silence')
		current_context.pattern_name = nil
	end
end

local function play_sample(variation)
	silence_sample()
	current_context.pattern_name = current_context.sample
	local cmd = string.format(
		'p "%s" $ s "%s:%s" # n %d # orbit 7',
		current_context.pattern_name,
		current_context.bank,
		current_context.sample,
		variation or 0
	)
	tidal_send(cmd)
end

function M.show_sound_banks()
	current_context.data = loader.load_dirt_samples()
	if not current_context.data or not current_context.data.samps then
		return
	end

	local items = create_items(current_context.data.samps, UI_CONFIG.banks.formatter)

	safe_fzf_exec(items, {
		prompt = UI_CONFIG.banks.prompt,
		winopts = { height = 0.9, width = UI_CONFIG.banks.width, row = 0.1 },
		default_action = function(value)
			current_context.bank = value
			M.show_samples()
		end,
	})
end

function M.show_samples()
	if not current_context.bank then
		return
	end
	local bank_data = current_context.data.samps[current_context.bank] or {}

	local items = create_items(bank_data, UI_CONFIG.samples.formatter)

	safe_fzf_exec(items, {
		prompt = UI_CONFIG.samples.prompt,
		winopts = { height = 0.9, width = UI_CONFIG.samples.width, row = 0.1 },
		default_action = function(value)
			vim.api.nvim_put({ value .. " " }, "c", true, true)
		end,
		play_action = function(value, attrs)
			current_context.sample = value
			play_sample(0)
		end,
		nav_action = function(value, attrs)
			current_context.sample = value
			if (attrs.variations or 0) > 1 then
				M.show_variations()
			else
				play_sample(0)
			end
		end,
		back_action = M.show_sound_banks,
	})
end

function M.show_variations()
	if not current_context.bank or not current_context.sample then
		return
	end
	local attrs = current_context.data.samps[current_context.bank][current_context.sample]
	local variations = math.max(0, attrs.variations or 0)

	local items = {}
	for i = 0, variations - 1 do
		table.insert(items, {
			text = UI_CONFIG.variations.formatter(i),
			value = i,
		})
	end

	safe_fzf_exec(items, {
		prompt = UI_CONFIG.variations.prompt,
		winopts = { height = 0.6, width = UI_CONFIG.variations.width, row = 0.2 },
		default_action = function(value)
			local insert = current_context.sample
			if value > 0 then
				insert = insert .. ":" .. value
			end
			vim.api.nvim_put({ insert .. " " }, "c", true, true)
		end,
		play_action = function(value)
			play_sample(value)
		end,
		back_action = M.show_samples,
	})
end

return M
