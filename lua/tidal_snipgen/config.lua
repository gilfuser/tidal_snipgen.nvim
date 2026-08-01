local M = {}

M.default_config = {
	samples_path = nil, -- Will be set in setup function
	output_path = nil, -- Will be set in setup function
	monitor_orbit = 6, -- orbit usado pra pré-escutar samples (ctrl-s na UI);
	-- pode ser mudado a qualquer momento com :TidalSnipgenSetMonitorOrbit
	keymaps = {
		show_banks = "<leader>sb",
		show_all_samples = "<leader>sa", -- pesquisa achatada (todos os bancos+samples)
		-- Atalhos usados DENTRO do picker fzf-lua (podem ser sobrescritos
		-- individualmente; não precisam de todas as chaves).
		fzf = {
			forward = "ctrl-l", -- entra no próximo nível (sample -> variação)
			backward = "alt-h", -- volta um nível (ctrl-h/ctrl-b têm conflitos, ver ui.lua)
			play = "ctrl-s", -- toca o item selecionado, sem fechar a UI
		},
	},
	auto_generate = true,
	fzf_layout = {
		width = 0.35,
		height = 0.9,
		border = "rounded",
	},
	-- auto_discover = true,
}

M.user_config = vim.deepcopy(M.default_config)

function M.setup(user_config)
	local paths = require("tidal_snipgen.paths")
	local dirmanager = require("tidal_snipgen.dir_manager")

	-- Resolve paths
	M.default_config.samples_path = paths.resolve_samples_dir()
	M.default_config.output_path = paths.expand_path("~/.config/nvim/lua/assets/snipgen_tidal.lua")

	M.user_config = vim.tbl_deep_extend("force", M.default_config, user_config or {})

	-- Validate output_path format
	if M.user_config.output_path then
		-- local sep = package.config:sub(1, 1)
		-- M.user_config.output_path = M.user_config.output_path:gsub("[/\\]+$", "") .. sep
		M.user_config.output_path = paths.expand_path(M.user_config.output_path)
	end

	-- Auto-create temp dir on setup
	dirmanager.ensure_temp_dir()

	-- If user provides custom path, write it immediately
	if user_config and user_config.custom_samples_path then
		dirmanager.write_samples_path(user_config.custom_samples_path)
	end
end

return M
