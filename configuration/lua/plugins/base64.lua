vim.api.nvim_create_user_command("ConBase64Encode", function(opts)
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

vim.api.nvim_create_user_command("ConBase64Decode", function(opts)
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

vim.api.nvim_create_user_command("GenSecret", function()
	local handle = io.popen("head -c 48 /dev/urandom | base64 | tr -d '=\\n' | tr '+/' '-_'")
	if not handle then
		vim.notify("Failed to run entropy command", vim.log.levels.ERROR)
		return
	end
	local secret = handle:read("*a")
	handle:close()
	vim.api.nvim_put({ vim.trim(secret) }, "l", true, true)
end, { desc = "Insert JWT secret" })
