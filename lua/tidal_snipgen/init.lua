-- init.lua
local config = require("tidal_snipgen.config")
local generate = require("tidal_snipgen.generate")
local ui = require("tidal_snipgen.ui")
local loader = require("tidal_snipgen.yaml_loader")
local dirman = require("tidal_snipgen.dir_manager")

-- Ensure normalized temp directory
dirman.ensure_temp_dir()

-- Handle Windows paths in user config
if user_config and user_config.custom_samples_path then
	user_config.custom_samples_path = dirman.normalize_path(user_config.custom_samples_path)
end

local M = {}

function M.reload_samples()
	local data = loader.load_dirt_samples()

	if data and data.samps then
		generate.generate(data.samps)
	else
		vim.notify("No sample data found", vim.log.levels.WARN)
	end
end

function M.setup(user_config)
	config.setup(user_config)
	dirman.ensure_temp_dir()

	-- Auto-require generated snippets
	vim.schedule(function()
		pcall(require, "assets.snipgen_tidal")
	end)

	-- Create commands
	vim.api.nvim_create_user_command("TidalSnipgenGenerate", function()
		generate.generate()
	end, {})

	vim.api.nvim_create_user_command("TidalSnipgenShowBanks", function()
		ui.show_sound_banks()
	end, {})

	vim.api.nvim_create_user_command("TidalSnipgenSearchAll", function()
		ui.show_all_samples()
	end, {})
	-- Independente de TidalSnipgenShowBanks: essa é a busca achatada
	-- (banco+sample numa lista só), pra quando você sabe mais ou menos o
	-- nome do sample e não quer entrar banco por banco procurando.

	-- monitor_orbit precisa poder mudar em qualquer momento (não só no
	-- setup), então em vez de só um valor de config estático, expomos um
	-- comando. play_sample() em ui.lua já lê config.user_config.monitor_orbit
	-- toda vez que toca um sample, então mudar isso aqui já vale imediatamente
	-- pro próximo ctrl-s, sem precisar reiniciar/recarregar nada.
	vim.api.nvim_create_user_command("TidalSnipgenSetMonitorOrbit", function(cmd_opts)
		if cmd_opts.args == "" then
			vim.notify("tidal_snipgen: monitor_orbit atual = " .. tostring(config.user_config.monitor_orbit or 6))
			return
		end
		local orbit = tonumber(cmd_opts.args)
		if not orbit then
			vim.notify("tidal_snipgen: uso: :TidalSnipgenSetMonitorOrbit <número>", vim.log.levels.ERROR)
			return
		end
		config.user_config.monitor_orbit = orbit
		vim.notify("tidal_snipgen: monitor_orbit = " .. orbit)
	end, {
		nargs = "?",
		desc = "Consulta (sem argumento) ou define o orbit usado pra pré-escutar samples",
	})

	vim.api.nvim_create_user_command("TidalSnipgenRefreshCps", function()
		local cps = require("tidal_snipgen.cps")
		cps.refresh_cps(function(value)
			if value then
				vim.notify(string.format("tidal_snipgen: cps = %.4f", value))
			else
				vim.notify(
					"tidal_snipgen: não consegui ler o cps (tidal.nvim rodando? getcps respondeu?)",
					vim.log.levels.WARN
				)
			end
		end)
	end, { desc = "Força uma consulta do cps atual ao Tidal, pra atualizar as frações de ciclo na UI" })

	vim.api.nvim_create_user_command("TidalSnipgenDebugCps", function()
		require("tidal_snipgen.cps").debug_refresh_cps()
	end, { desc = "Mostra passo a passo a tentativa de consultar o cps, pra debugar quando não funciona" })

	-- Set keymaps
	if config.user_config.keymaps.show_banks then
		vim.keymap.set(
			"n",
			config.user_config.keymaps.show_banks,
			"<cmd>TidalSnipgenShowBanks<CR>",
			{ silent = true, noremap = true }
		)
	end

	if config.user_config.keymaps.show_all_samples then
		vim.keymap.set(
			"n",
			config.user_config.keymaps.show_all_samples,
			"<cmd>TidalSnipgenSearchAll<CR>",
			{ silent = true, noremap = true }
		)
	end

	-- Handle auto-generation
	if config.user_config.auto_generate then
		vim.schedule(function()
			M.reload_samples()
		end)
	end
end

return M
