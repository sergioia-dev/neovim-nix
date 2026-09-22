vim.api.nvim_create_user_command("B64Encode", function(opts)
	local lines = vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false)
	local input = table.concat(lines, "")
	input = input:gsub("%s+", "") -- ← strip all whitespace

	local out = vim.fn.system({ "base64", "-w", "0" }, input)
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_err_writeln("base64 encode failed: " .. out)
		return
	end
	out = out:gsub("\n$", "")

	vim.api.nvim_buf_set_lines(0, opts.line1 - 1, opts.line2, false, { out })
end, { range = true })

vim.api.nvim_create_user_command("B64Decode", function(opts)
	local lines = vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false)
	local input = table.concat(lines, ""):gsub("%s+", "")
	input = input:gsub("-", "+"):gsub("_", "/")
	input = input .. string.rep("=", (4 - #input % 4) % 4)

	local flag = vim.fn.has("mac") == 1 and "-D" or "-d"
	local out = vim.fn.system({ "base64", flag }, input)
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_err_writeln("base64 decode failed: " .. out)
		return
	end
	out = out:gsub("\n$", "")

	vim.api.nvim_buf_set_lines(0, opts.line1 - 1, opts.line2, false, { out })
end, { range = true })
