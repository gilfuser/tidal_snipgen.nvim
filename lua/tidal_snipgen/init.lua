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
	if not data.yaml_data.samps then
		vim.notify("No sample data found", vim.log.levels.WARN)
		return
	end
	generate.generate(data.yaml_data.samps) -- Changed to match generate.lua exports
end

function M.setup(user_config)
	config.setup(user_config)
	dirman.ensure_temp_dir()

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
