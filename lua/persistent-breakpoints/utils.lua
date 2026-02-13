local cfg = require('persistent-breakpoints.config')
local M = {}

M.create_path = function(path)
	vim.fn.mkdir(path, "p")
end

M.get_path_sep = function()
	if jit then
		if jit.os == "Windows" then
			return '\\'
		else
			return '/'
		end
	else
		return package.config:sub(1, 1)
	end
end

-- Convert absolute path to relative path (relative to cwd)
-- Only used when `filename` is configured for portable breakpoints
M.to_relative_path = function(abs_path)
	if not cfg.filename or not abs_path or abs_path == "" then
		return abs_path
	end
	local cwd = vim.fn.getcwd()
	local path_sep = M.get_path_sep()
	-- Ensure cwd ends with separator for proper matching
	if cwd:sub(-1) ~= path_sep then
		cwd = cwd .. path_sep
	end
	-- Check if abs_path starts with cwd
	if abs_path:sub(1, #cwd) == cwd then
		return abs_path:sub(#cwd + 1)
	end
	-- If not under cwd, return absolute path as-is
	return abs_path
end

-- Convert relative path back to absolute path
-- Only used when `filename` is configured for portable breakpoints
M.to_absolute_path = function(path)
	if not cfg.filename or not path or path == "" then
		return path
	end
	local path_sep = M.get_path_sep()
	-- If path is already absolute, return as-is
	if path:sub(1, 1) == path_sep or (jit and jit.os == "Windows" and path:match("^%a:[/\\]")) then
		return path
	end
	-- Convert relative path to absolute
	return vim.fn.getcwd() .. path_sep .. path
end

M.get_bps_path = function ()
	local path_sep = M.get_path_sep()

	-- If filename is configured, use it directly (portable across directories)
	if cfg.filename then
		return cfg.save_dir .. path_sep .. cfg.filename .. '.json'
	end

	-- Otherwise, use absolute path (original behavior)
	local base_filename = vim.fn.getcwd()

	if jit and jit.os == 'Windows' then
		base_filename = base_filename:gsub(':', '_')
	end

	local cp_filename = base_filename:gsub(path_sep, '_') .. '.json'
	return cfg.save_dir .. path_sep .. cp_filename
end

M.load_bps = function (path)
	local fp = io.open(path,'r')
	local bps = {}
	if fp ~= nil then
		local load_bps_raw = fp:read('*a')
		bps = vim.fn.json_decode(load_bps_raw)
		fp:close()
	end
	return bps
end

M.write_bps = function (path, bps)
	bps = bps or {}
	assert(type(bps) == 'table', "The persistent breakpoints should be stored in a table. Usually it is not the user's problem if you did not call the write_bps function explicitly.")

	-- Lazily create directory only when saving breakpoints
	local dir = vim.fn.fnamemodify(path, ':h')
	vim.fn.mkdir(dir, "p")

	local fp = io.open(path, 'w+')
	if fp == nil then
		vim.notify('Failed to save checkpoints. File: ' .. vim.fn.expand('%'), 'WARN')
		return false
	else
		fp:write(vim.fn.json_encode(bps))
		fp:close()
		return true
	end
end

return M
