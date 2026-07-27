local loader = require("tidal_snipgen.yaml_loader")
local fzf_lua = require("fzf-lua")
local config = require("tidal_snipgen.config")
local M = {}

local default_fzf_keymaps = {
	forward = "ctrl-l", -- entra no próximo nível (banco -> sample -> variação)
	backward = "ctrl-b", -- volta um nível. NOTA: era "ctrl-h", mas em muitos
	-- terminais Ctrl-H manda o mesmo byte que Backspace, então editar a
	-- query com Backspace podia disparar "voltar" sem querer (ou parecer
	-- que a tecla não fazia nada). ctrl-b não tem esse conflito.
	play = "ctrl-s", -- toca o sample/variação selecionado, sem fechar a UI
	search_all = "ctrl-a", -- pesquisa achatada: todos os bancos+samples de uma vez
}
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

-- bank_hint (opcional): "carimba" cada item com o banco de origem. Usado
-- pelo picker achatado (show_all_samples), onde os itens vêm de vários
-- bancos ao mesmo tempo e precisamos lembrar de qual banco cada um veio.
local function create_items(data, formatter, bank_hint)
	local items = {}
	for key, attrs in pairs(data) do
		if type(attrs) == "table" then
			table.insert(items, {
				text = formatter(key, attrs),
				value = key,
				attrs = attrs,
				bank = bank_hint,
			})
		end
	end
	table.sort(items, function(a, b)
		return a.value < b.value
	end)
	return items
end

local current_pattern = nil -- Track currently playing pattern

-- tidal.nvim (skmecs) não expõe comandos Ex como ":TidalSend1" (esse era
-- do antigo vim-tidal). Em vez disso ele expõe uma API Lua:
-- require("tidal").api.send(text). Usamos essa API diretamente.
local function send_to_tidal(text)
	local ok, tidal = pcall(require, "tidal")
	if not ok or not tidal.api or not tidal.api.send then
		vim.notify(
			"tidal_snipgen: não foi possível achar require('tidal').api.send — tidal.nvim está carregado/instalado?",
			vim.log.levels.ERROR
		)
		return
	end
	tidal.api.send(text)
end

local function silence_sample()
	if current_pattern then
		local silence_cmd = string.format('p "%s" silence', current_pattern)
		vim.schedule(function()
			send_to_tidal(silence_cmd)
		end)
		current_pattern = nil
	end
end

local function play_sample(variation)
	silence_sample()
	local sample = current_context.sample or "sample"
	local var = tonumber(variation) or 0
	local monitor_orbit = tonumber(config.user_config.monitor_orbit) or 6
	current_pattern = string.format("%s_%d", sample, os.time())

	local cmd = string.format('p "%s" $ s "%s" # n %d # orbit %d', current_pattern, sample, var, monitor_orbit)
	vim.schedule(function()
		send_to_tidal(cmd)
	end)

	local pattern_name = current_pattern
	vim.defer_fn(function()
		if current_pattern == pattern_name then
			silence_sample()
			current_pattern = nil
		end
	end, 16000)
end

--- Executa um picker fzf-lua.
--- opts:
---   prompt            (string)
---   nav_forward(value, attrs, bank)   -- entra no próximo nível
---   nav_backward()                    -- volta um nível (omitir se não houver nível acima)
---   play_action(value, attrs, bank)   -- toca o sample/variação SEM fechar a UI
---   default_action(value, attrs, bank) -- <CR>: insere no buffer
---   enable_search_all (bool, default true) -- disponibiliza o atalho de busca achatada
local function safe_fzf_exec(items, opts)
	local items_map = {}
	local items_str = {}

	for _, item in ipairs(items) do
		if item.text and item.value then
			table.insert(items_str, item.text)
			items_map[item.text] = {
				value = item.value,
				attrs = item.attrs,
				bank = item.bank,
			}
		end
	end

	if #items_str == 0 then
		return
	end

	local layout = {
		width = config.user_config.fzf_layout.width or 0.3,
		height = config.user_config.fzf_layout.height or 0.9,
		border = config.user_config.fzf_layout.border or "rounded",
		row = config.user_config.fzf_layout.row or 0.1,
		col = config.user_config.fzf_layout.col or 1,
	}

	local win_width = math.floor(vim.o.columns * layout.width)
	local win_height = math.floor(vim.o.lines * layout.height)
	local win_row = math.floor(vim.o.lines * layout.row)
	local win_col = math.floor(vim.o.columns - win_width - 1)

	local actions = {
		[convert_key(fzf_keymaps.forward)] = function(selected)
			if opts.nav_forward and #selected > 0 then
				local data = items_map[selected[1]]
				opts.nav_forward(data.value, data.attrs, data.bank)
			end
			return false
		end,
		["default"] = function(selected)
			if opts.default_action and #selected > 0 then
				local data = items_map[selected[1]]
				opts.default_action(data.value, data.attrs, data.bank)
			end
			return true
		end,
	}

	if opts.nav_backward then
		actions[convert_key(fzf_keymaps.backward)] = function()
			opts.nav_backward()
			return false
		end
	end

	if opts.play_action then
		-- exec_silent: roda a função sem fechar (nem precisar "resumir") a
		-- janela do fzf-lua. É o jeito nativo, moderno, de manter a UI
		-- aberta enquanto você escuta várias variações em sequência —
		-- substitui qualquer hack manual de fechar/reabrir ou de
		-- continue()/resume() (que dependia de uma variável "fzf_win" que
		-- nunca chegava a ser definida em lugar nenhum).
		actions[convert_key(fzf_keymaps.play)] = {
			fn = function(selected)
				if selected and #selected > 0 then
					local data = items_map[selected[1]]
					opts.play_action(data.value, data.attrs, data.bank)
				end
			end,
			exec_silent = true,
		}
	end

	if opts.enable_search_all ~= false then
		actions[convert_key(fzf_keymaps.search_all)] = function()
			vim.schedule(M.show_all_samples)
			return false
		end
	end

	local fzf_opts = {
		prompt = opts.prompt,
		winopts = {
			height = win_height,
			width = win_width,
			row = win_row,
			col = win_col,
			border = layout.border,
			title = opts.prompt:gsub(">.*", ""),
			focusable = true,
			relative = "editor",
		},
		actions = actions,
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
		end,
		nav_backward = M.show_sound_banks,
		play_action = function(value)
			current_context.sample = value
			play_sample(0)
		end,
		default_action = function(value)
			current_context.sample = value
			vim.api.nvim_put({ value .. " " }, "c", true, true)
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

--- Picker "achatado": lista banco+sample de TODOS os bancos numa lista só,
--- pra dar pra pesquisar direto sem precisar entrar em cada banco primeiro.
--- Disponível a partir de qualquer nível via o atalho "search_all"
--- (ctrl-a por padrão), ou diretamente com :TidalSnipgenSearchAll.
function M.show_all_samples()
	current_context.data = loader.load_dirt_samples()
	if not current_context.data or not current_context.data.samps then
		return
	end

	local items = {}
	for bank_name, bank_data in pairs(current_context.data.samps) do
		local is_drummachine = bank_data.drummachine or false
		for sample_name, sample_attrs in pairs(bank_data) do
			if type(sample_attrs) == "table" and sample_name ~= "drummachine" then
				local attrs = vim.tbl_extend("keep", sample_attrs, {
					drummachine = is_drummachine,
				})
				table.insert(items, {
					text = string.format("%-18s %s", bank_name, UI_CONFIG.samples.formatter(sample_name, attrs)),
					value = sample_name,
					attrs = attrs,
					bank = bank_name,
				})
			end
		end
	end

	table.sort(items, function(a, b)
		return a.text < b.text
	end)

	safe_fzf_exec(items, {
		prompt = "All Samples> ",
		enable_search_all = false, -- já estamos na busca achatada
		nav_forward = function(value, attrs, bank)
			current_context.bank = bank
			current_context.sample = value
			if (attrs.variations or 0) > 1 then
				M.show_variations()
			else
				play_sample(0)
			end
		end,
		nav_backward = M.show_sound_banks,
		play_action = function(value, attrs, bank)
			current_context.bank = bank
			current_context.sample = value
			play_sample(0)
		end,
		default_action = function(value, attrs, bank)
			current_context.bank = bank
			current_context.sample = value
			vim.api.nvim_put({ value .. " " }, "c", true, true)
		end,
	})
end

return M
