local M = {}

function M.file_modified_time(file_path)
	local file = io.popen("stat -c %Y " .. file_path)
	if file then
		local last_modified = file:read("*n")
		file:close()
		return last_modified
	end
	return nil
end

return M
