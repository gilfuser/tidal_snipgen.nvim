--  ~/.config/nvim/lua/plugins/tidal_snipgen/init.lua
local sound_banks = require("tidal_snipgen.show_sound_banks")

-- Paths
local yaml_file_path = vim.fn.expand("~/Samples/dirt_samps.yaml")

-- Generate and load the snippets
require("tidal_snipgen.generate_tidal_snippets")
-- Command to toggle sound banks floating window

vim.api.nvim_create_user_command("ShowSoundBanks", function()
	sound_banks.display_sound_banks(yaml_file_path)
end, {})

-- Keybinding to toggle sound banks floating window
vim.api.nvim_set_keymap("n", "<leader>sb", ":ShowSoundBanks<CR>", { noremap = true, silent = true })
