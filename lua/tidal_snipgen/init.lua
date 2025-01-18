local snippet_generator = require("tidal_snipgen.snippet_generator")
-- Paths
local yaml_file_path = vim.fn.expand("~/Samples/dirt_samps.yaml")
local snippets_file_path = vim.fn.expand("~/.config/nvim/snippets/tidal.code-snippets")

snippet_generator.check_and_generate_snippets(yaml_file_path, snippets_file_path)

-- Load the snippets
require("luasnip.loaders.from_vscode").load_standalone({ path = snippets_file_path })

-- Ensure the buffer filetype is set to JSON for the snippets file
vim.cmd([[autocmd BufRead,BufNewFile ~/.config/nvim/snippets/tidal.code-snippets set filetype=json]])
