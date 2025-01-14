local format_json = {}

function format_json.format_json_file(snippets_file_path)
	-- Use a temporary buffer to format the JSON file
	local bufnr = vim.api.nvim_create_buf(false, true) -- Create a new unlisted buffer
	if not bufnr then
		print("Error creating temporary buffer")
		return
	end

	-- Read the content of the JSON file into the buffer
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, vim.fn.readfile(snippets_file_path))
	vim.api.nvim_buf_set_option(bufnr, "filetype", "json")

	-- Format the buffer using :JsonFormatFile
	vim.api.nvim_buf_call(bufnr, function()
		vim.cmd("JsonFormatFile")
	end)

	-- Write the formatted content back to the JSON file
	vim.fn.writefile(vim.api.nvim_buf_get_lines(bufnr, 0, -1, true), snippets_file_path)

	-- Delete the temporary buffer
	vim.api.nvim_buf_delete(bufnr, { force = true })
end

return format_json
