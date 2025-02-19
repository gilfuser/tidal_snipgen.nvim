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

	-- Set keymaps
	if config.user_config.keymaps.show_banks then
		vim.keymap.set(
			"n",
			config.user_config.keymaps.show_banks,
			"<cmd>TidalSnipgenShowBanks<CR>",
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
