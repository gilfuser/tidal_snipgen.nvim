-- In tidal_snipgen/config.lua
local paths = require("tidal_snipgen.paths")
local dirmanager = require("tidal_snipgen.dir_manager")
local function get_platform_sep()
	return package.config:sub(1, 1) -- Returns "/" for Unix, "\" for Windows
end

local function expand_path(path)
	local sep = get_platform_sep()
	local home = vim.env.HOME or vim.env.USERPROFILE
	return path:gsub("^~", home):gsub("/", sep)
end

local M = {}

M.default_config = {
	samples_path = paths.get_platform_default(),
	output_path = nil, -- Let user override
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

	-- Auto-create temp dir on setup
	dirmanager.ensure_temp_dir()

	-- If user provides custom path, write it immediately
	if user_config and user_config.custom_samples_path then
		dirmanager.write_samples_path(user_config.custom_samples_path)
	end
end

return M
