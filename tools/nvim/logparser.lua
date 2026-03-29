local M = {
	config = {
		bin = "logparser",
	},
}

local function get_buf_text(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	return table.concat(lines, "\n")
end

local function is_executable(path)
	return vim.fn.executable(path) == 1
end

local function replace_buffer(lines)
	local buf = vim.api.nvim_get_current_buf()

	-- allow modification temporarily
	local was_modifiable = vim.bo[buf].modifiable
	vim.bo[buf].modifiable = true

	-- replace entire buffer
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	-- restore modifiable state
	vim.bo[buf].modifiable = was_modifiable
end

function M.run(opts)
	local args = opts.fargs or {}
	local input = get_buf_text(0)
	local bin = M.config.bin

	if not is_executable(bin) then
		vim.notify("logparser binary not found or not executable: " .. bin, vim.log.levels.ERROR)
		return
	end

	local cmd = { bin }
	vim.list_extend(cmd, args)

	local output = vim.fn.systemlist(cmd, input)
	local code = vim.v.shell_error

	if code ~= 0 then
		vim.notify("logparser failed (" .. tostring(code) .. "):\n" .. table.concat(output, "\n"), vim.log.levels.ERROR)
		return
	end

	-- Replace current buffer with output
	replace_buffer(output)

	-- Optional: rename buffer to reflect filter chain
	local suffix = (#args > 0) and (" " .. table.concat(args, " ")) or ""
	local name = "[logparser" .. suffix .. "]"
	pcall(vim.api.nvim_buf_set_name, 0, name)
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	vim.api.nvim_create_user_command("Logparser", function(command_opts)
		M.run(command_opts)
	end, {
		nargs = "*",
	})
end

return M
