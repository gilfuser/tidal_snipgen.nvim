local file_utils = require("tidal_snipgen.file_utils")
local snippet_generator = require("tidal_snipgen.snippet_generator")

-- Paths
local yaml_file_path = vim.fn.expand("~/Samples/dirt_samps.yaml")
local snippets_file_path = vim.fn.expand("~/.config/nvim/snippets/tidal.code-snippets")

-- Generate snippets if the YAML file has been updated
local last_modified = file_utils.file_modified_time(yaml_file_path)
if last_modified and last_modified ~= vim.g.snippet_yaml_last_modified then
	vim.g.snippet_yaml_last_modified = last_modified
	snippet_generator.generate_snippets(yaml_file_path, snippets_file_path)
end

-- Load the snippets
require("luasnip.loaders.from_vscode").load_standalone({ path = snippets_file_path })

-- Ensure the buffer filetype is set to JSON for the snippets file
vim.cmd([[autocmd BufRead,BufNewFile ~/.config/nvim/snippets/tidal.code-snippets set filetype=json]])
