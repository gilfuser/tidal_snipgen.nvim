local loader = require("tidal_snipgen.yaml_loader")
local fzf_lua = require("fzf-lua")
local config = require("tidal_snipgen.config")
local cps = require("tidal_snipgen.cps")
local M = {}

local default_fzf_keymaps = {
	forward = "ctrl-l", -- entra no próximo nível (banco -> sample -> variação)
	backward = "alt-h", -- volta um nível. NOTA: "ctrl-h" colide com Backspace
	-- em muitos terminais (mesmo byte), e "ctrl-b" é reservado GLOBALMENTE
	-- pelo próprio fzf-lua (= "half-page-up", nível abaixo da nossa tabela
	-- de actions, então nunca dava pra sobrescrever). Combinações "alt-"
	-- são enviadas como escape sequence por qualquer terminal, então nunca
	-- colidem com edição de texto nem com os binds nativos do fzf.
	-- ATENÇÃO: em alguns terminais (principalmente no Windows) combinações
	-- Alt- podem ser engolidas pelo próprio terminal/SO antes de chegar no
	-- Neovim. Se "alt-h" não fizer nada aí, troque em keymaps.fzf.backward
	-- pra outra coisa livre (veja o comentário sobre teclas reservadas
	-- logo abaixo de default_fzf_keymaps, no README).
	play = "ctrl-s", -- toca o sample/variação selecionado, sem fechar a UI
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

--- Formata a duração de um sample como fração(ões) de ciclo, usando o cps
--- mais recente conhecido (ver cps.lua). Sample sempre carrega min_dur e
--- max_dur (podem ser iguais). Cai de volta pra segundos quando ainda não
--- temos um cps (nenhuma consulta bem-sucedida ao GHCi ainda).
local function format_duration(attrs)
	local min_dur = tonumber(attrs.min_dur)
	local max_dur = tonumber(attrs.max_dur)
	if not min_dur or not max_dur then
		return ""
	end

	if math.abs(max_dur - min_dur) < 0.001 then
		return cps.duration_to_cycle_fraction(min_dur) or string.format("%.2fs", min_dur)
	end

	local min_frac = cps.duration_to_cycle_fraction(min_dur)
	local max_frac = cps.duration_to_cycle_fraction(max_dur)
	if min_frac and max_frac then
		return string.format("%s~%s", min_frac, max_frac)
	end
	return string.format("%.2f~%.2fs", min_dur, max_dur)
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
		-- name_width: calculado dinamicamente por quem monta a lista (ver
		-- show_samples/show_all_samples), em vez de um valor fixo — nomes
		-- de sample variam muito de tamanho, e um preenchimento fixo largo
		-- (25 chars) deixava um espaço enorme entre o nome e os números
		-- quando os nomes eram curtos.
		formatter = function(sample, attrs, name_width)
			name_width = name_width or 20
			return string.format(
				"%-" .. name_width .. "s %4d  %s",
				sample:sub(1, name_width), -- Column 1: Sample name
				attrs.variations or 0, -- Column 2: Variation count
				format_duration(attrs) -- Column 3: duração (fração de ciclo, ou segundos se cps indisponível)
			)
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
	return_to = nil, -- pra onde "voltar" a partir de show_variations (show_samples ou show_all_samples, dependendo de por onde você entrou)
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
---   nav_forward(value, attrs, bank)   -- entra no próximo nível / toca (se for nível folha)
---   nav_backward()                    -- volta um nível (omitir se não houver nível acima)
---   play_action(value, attrs, bank)   -- toca o sample/variação SEM fechar a UI
---   default_action(value, attrs, bank) -- <CR>: insere no buffer (fecha a UI)
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

	-- IMPORTANTE (fzf-lua): esse "do_not_close"/"noclose" que existe no
	-- código do fzf-lua só decide se a JANELA (o wrapper do Neovim) fica
	-- aberta depois — mas isso roda DEPOIS que o processo `fzf` em si já
	-- saiu (fzf.raw_fzf() já retornou nesse ponto). Ou seja, `noclose`
	-- sozinho NÃO impede o `fzf` de terminar; só evita destruir a janela
	-- em volta de um processo já morto — o que na prática deixa a UI num
	-- estado quebrado ("[Process Exited]"). Quem realmente evita o `fzf`
	-- de sair é `exec_silent = true`: isso liga a tecla a um bind do tipo
	-- "execute-silent(...)", que o `fzf` processa SEM encerrar. É o que
	-- forward/backward/play usam abaixo.
	local actions = {
		[convert_key(fzf_keymaps.forward)] = {
			fn = function(selected)
				if opts.nav_forward and selected and #selected > 0 then
					local data = items_map[selected[1]]
					opts.nav_forward(data.value, data.attrs, data.bank)
				end
			end,
			exec_silent = true,
		},
		["default"] = function(selected)
			if opts.default_action and #selected > 0 then
				local data = items_map[selected[1]]
				opts.default_action(data.value, data.attrs, data.bank)
			end
			return true
		end,
	}

	if opts.nav_backward then
		actions[convert_key(fzf_keymaps.backward)] = {
			fn = function()
				opts.nav_backward()
			end,
			exec_silent = true,
		}
	end

	if opts.play_action then
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

--- Navegação hierárquica normal: bancos -> samples (de UM banco) -> variações.
--- Digitar no picker filtra só os NOMES DOS BANCOS aqui. Pra pesquisar
--- banco+sample ao mesmo tempo, veja M.show_all_samples() /
--- :TidalSnipgenSearchAll.
function M.show_sound_banks()
	cps.refresh_cps() -- assíncrono; usa o cache pra essa renderização, atualiza pra próxima
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

	-- Largura da coluna de nome calculada a partir dos nomes reais desse
	-- banco (limitada entre 8 e 30 chars), em vez de um valor fixo.
	local name_width = 8
	for sample_name, sample_attrs in pairs(bank_data) do
		if type(sample_attrs) == "table" and sample_name ~= "drummachine" then
			name_width = math.max(name_width, math.min(#sample_name, 30))
		end
	end

	local items = {}
	for sample_name, sample_attrs in pairs(bank_data) do
		if type(sample_attrs) == "table" and sample_name ~= "drummachine" then
			local attrs = vim.tbl_extend("keep", sample_attrs, {
				drummachine = is_drummachine,
			})

			table.insert(items, {
				text = UI_CONFIG.samples.formatter(sample_name, attrs, name_width),
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
				current_context.return_to = M.show_samples
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
		nav_backward = current_context.return_to or M.show_samples,
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
--- Independente da navegação hierárquica (M.show_sound_banks) — não
--- substitui ela, é um jeito alternativo de chegar num sample.
--- Acesse com <leader>sa ou :TidalSnipgenSearchAll.
function M.show_all_samples()
	cps.refresh_cps() -- assíncrono; usa o cache pra essa renderização, atualiza pra próxima
	current_context.data = loader.load_dirt_samples()
	if not current_context.data or not current_context.data.samps then
		return
	end

	-- Larguras de coluna calculadas a partir dos dados reais (limitadas),
	-- em vez de valores fixos que deixavam espaço demais sobrando quando
	-- os nomes eram curtos.
	local bank_width, name_width = 8, 8
	for bank_name, bank_data in pairs(current_context.data.samps) do
		bank_width = math.max(bank_width, math.min(#bank_name, 22))
		for sample_name, sample_attrs in pairs(bank_data) do
			if type(sample_attrs) == "table" and sample_name ~= "drummachine" then
				name_width = math.max(name_width, math.min(#sample_name, 30))
			end
		end
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
					text = string.format(
						"%-" .. bank_width .. "s %s",
						bank_name,
						UI_CONFIG.samples.formatter(sample_name, attrs, name_width)
					),
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
		nav_forward = function(value, attrs, bank)
			current_context.bank = bank
			current_context.sample = value
			if (attrs.variations or 0) > 1 then
				current_context.return_to = M.show_all_samples
				M.show_variations()
			else
				play_sample(0)
			end
		end,
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
