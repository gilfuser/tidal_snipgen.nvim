local loader = require("tidal_snipgen.yaml_loader")
local fzf_lua = require("fzf-lua")
local config = require("tidal_snipgen.config")
local M = {}
local default_fzf_keymaps = { forward = "ctrl-l", backward = "ctrl-h", play = "ctrl-s" }
local user_fzf_keymaps = config.user_config.keymaps and config.user_config.keymaps.fzf
local fzf_keymaps = vim.tbl_deep_extend("force", {}, default_fzf_keymaps, user_fzf_keymaps or {})

local function convert_key(key)
	return key:lower()
		:gsub("<c%-", "ctrl-")
		:gsub("<a%-", "alt-")
		:gsub("<s%-", "shift-")
		:gsub("<leader>", "\\")
		:gsub("[<>]", "")
end

local function calculate_dynamic_height(items_count)
	local config = require("tidal_snipgen.config").user_config
	local term_height = vim.o.lines
	local padding = 4 -- Space for headers/borders
	-- Calculate ideal height
	local height = math.min(
		items_count + padding, -- Content-based height
		config.fzf_layout.max_height, -- User maximum
		term_height - padding -- Terminal limits
	)
	return math.max(height, config.fzf_layout.min_height)
end

local function create_persistent_action_handler(fn)
	return function(selected, _, fzf_win)
		-- Safe window continuation with error handling
		pcall(function()
			if fzf_win and fzf_win.continue then
				fzf_win:continue()
			end
		end)
		-- Execute handler and explicitly return false
		if selected and #selected > 0 then
			fn(selected)
		end
		return false
	end
end

local UI_CONFIG = {
	banks = {
		prompt = "Sound Banks> ",
		formatter = function(bank, attrs)
			return string.format("%-20s %s", bank, attrs.drummachine and "⚡" or "")
		end,
	},
	samples = {
		prompt = "Samples> ",
		formatter = function(sample, attrs)
			-- Get duration qualifier if not drummachine
			local duration = ""
			if not attrs.drummachine then
				local durations = {
					is_shorter = "shorter",
					is_short = "short",
					is_long = "long",
					is_longer = "longer",
				}
				for attr, label in pairs(durations) do
					if attrs[attr] then
						duration = label
						break
					end
				end
			end
			return string.format(
				"%-10s %4d %10s",
				sample:sub(1, 25), -- Column 1: Sample name
				attrs.variations or 0,
				duration -- Column 2: Duration qualifier
			) -- Column 3: Variation count
		end,
	},
	variations = {
		prompt = "Variations> ",
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

--[[ local function tidal_send(cmd)
	vim.schedule(function()
		vim.cmd("TidalSend1 " .. vim.api.nvim_replace_termcodes(cmd, true, true, true))
	end)
end ]]

local current_pattern = nil -- Track currently playing pattern

local function silence_sample()
	if current_pattern then
		local silence_cmd = string.format('p "%s" silence', current_pattern)
		-- Use native Neovim scheduling
		vim.schedule(function()
			vim.cmd.TidalSend1(silence_cmd)
		end)
		current_pattern = nil
	end
end

local function play_sample(variation)
	silence_sample()
	local bank = current_context.bank or "default_bank"
	local sample = current_context.sample or "sample"
	local var = tonumber(variation) or 0
	local monitor_orbit = tonumber(config.user_config.monitor_orbit) or 6
	current_pattern = string.format("%s_%s_%d", bank, sample, os.time())

	-- Optional: debug print to catch future nils
	-- print("bank:", bank, "sample:", sample, "var:", var, "monitor_orbit:", monitor_orbit)

	local cmd = string.format('p "%s" $ s "%s" # n %d # orbit %d', current_pattern, sample, var, monitor_orbit)
	vim.schedule(function()
		vim.cmd("noautocmd TidalSend1 " .. vim.api.nvim_replace_termcodes(cmd, true, true, true))
	end)
	-- Optionally, your auto-silence logic
	local pattern_name = current_pattern
	vim.defer_fn(function()
		if current_pattern == pattern_name then
			silence_sample()
			current_pattern = nil
		end
	end, 16000)
end

local function safe_fzf_exec(items, opts)
	local items_map = {}
	local items_str = {}

	-- Build items list
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

	-- Get layout config with proper fallbacks
	local layout = {
		width = config.user_config.fzf_layout.width or 0.3,
		height = config.user_config.fzf_layout.height or 0.9,
		border = config.user_config.fzf_layout.border or "rounded",
		row = config.user_config.fzf_layout.row or 0.1,
		col = config.user_config.fzf_layout.col or 1,
	}

	-- Calculate absolute positions (right-aligned)
	local win_width = math.floor(vim.o.columns * layout.width)
	local win_height = math.floor(vim.o.lines * layout.height)
	local win_row = math.floor(vim.o.lines * layout.row)
	local win_col = math.floor(vim.o.columns - win_width - 1)

	-- Configure FZF options
	local fzf_opts = {
		prompt = opts.prompt,
		winopts = {
			height = win_height,
			width = win_width,
			row = win_row,
			col = win_col,
			border = layout.border,
			title = opts.prompt:gsub(">.*", ""),
			persistent = true,
			focusable = true,
			relative = "editor",
		},
		actions = {
			[convert_key(fzf_keymaps.forward)] = function(selected)
				if opts.nav_forward and #selected > 0 then
					local data = items_map[selected[1]]
					opts.nav_forward(data.value, data.attrs)
				end
				return false
			end,
			[convert_key(fzf_keymaps.backward)] = function()
				if opts.nav_backward then
					opts.nav_backward()
				end
				return false
			end,
			[convert_key(fzf_keymaps.play)] = function(selected)
				if opts.play_action and #selected > 0 then
					local data = items_map[selected[1]]
					vim.schedule(function()
						opts.play_action(data.value, data.attrs)
					end)
				end
				return false
			end,
			["default"] = function(selected)
				if opts.default_action and #selected > 0 then
					local data = items_map[selected[1]]
					opts.default_action(data.value, data.attrs)
				end
				return true
			end,
		},
		fzf_opts = {
			["--no-exit-0"] = "",
		},
	}

	fzf_lua.fzf_exec(items_str, fzf_opts)
end

function M.show_sound_banks()
	current_context.data = loader.load_dirt_samples()
	if not current_context.data or not current_context.data.samps then
		return
	end
	local bank_keys = vim.tbl_keys(current_context.data.samps)
	if #bank_keys == 1 then
		current_context.bank = bank_keys[1]
		M.show_samples()
		return
	end

	local items = create_items(current_context.data.samps, UI_CONFIG.banks.formatter)

	safe_fzf_exec(items, {
		prompt = UI_CONFIG.banks.prompt,
		nav_forward = function(value)
			current_context.bank = value
			M.show_samples()
		end,
		default_action = function(value)
			vim.api.nvim_put({ value .. " " }, "c", true, true)
		end,
	})
end

function M.show_samples()
	if not current_context.bank then
		return
	end
	local bank_data = current_context.data.samps[current_context.bank] or {}
	local is_drummachine = bank_data.drummachine or false
	local items = {}
	for sample_name, sample_attrs in pairs(bank_data) do
		if type(sample_attrs) == "table" and sample_name ~= "drummachine" then
			-- Add drummachine status to sample attributes
			local attrs = vim.tbl_extend("keep", sample_attrs, {
				drummachine = is_drummachine,
			})

			table.insert(items, {
				text = UI_CONFIG.samples.formatter(sample_name, attrs),
				value = sample_name,
				attrs = attrs,
			})
		end
	end

	safe_fzf_exec(items, {
		prompt = UI_CONFIG.samples.prompt,
		nav_forward = function(value, attrs)
			current_context.sample = value
			if (attrs.variations or 0) > 1 then
				M.show_variations()
			else
				play_sample(0)
			end
			return false
		end,
		nav_backward = M.show_sound_banks,
		play_action = function(value)
			current_context.sample = value
			play_sample(0)
			return false -- Explicit return
		end,
		default_action = function(value)
			local insert = current_context.sample
			if value > 0 then
				insert = insert .. ":" .. value
			end
			vim.api.nvim_put({ insert .. " " }, "c", true, true)
		end,
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
		nav_backward = M.show_samples,
		play_action = function(value)
			play_sample(value)
			return false
		end,
		default_action = function(value)
			local insert = current_context.sample
			if value > 0 then
				insert = insert .. ":" .. value
			end
			vim.api.nvim_put({ insert .. " " }, "c", true, true)
			return false
		end,
	})
end

return M
