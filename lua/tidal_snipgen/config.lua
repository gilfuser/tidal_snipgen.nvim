local paths = require("tidal_snipgen.paths")
local dirmanager = require("tidal_snipgen.dir_manager")

local M = {}

M.default_config = {
	samples_path = paths.resolve_samples_dir(),
	output_path = paths.expand_path("~/.config/nvim/lua/assets/snipgen_tidal.lua"), -- Ensure this points to a file
	keymaps = {
		show_banks = "<leader>sb",
	},
	auto_generate = true,
	fzf_layout = {
		width = 0.2,
		height = 0.9,
		border = "rounded",
	},
	auto_discover = true,
}

M.user_config = vim.deepcopy(M.default_config)

function M.setup(user_config)
	M.user_config = vim.tbl_deep_extend("force", M.default_config, user_config or {})

	-- Validate output_path format
	if M.user_config.output_path then
		local sep = package.config:sub(1, 1)
		M.user_config.output_path = M.user_config.output_path:gsub("[/\\]+$", "")
	end

	-- Auto-create temp dir on setup
	dirmanager.ensure_temp_dir()

	-- If user provides custom path, write it immediately
	if user_config and user_config.custom_samples_path then
		dirmanager.write_samples_path(user_config.custom_samples_path)
	end
end

return M
