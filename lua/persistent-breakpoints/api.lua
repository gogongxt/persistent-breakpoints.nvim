local utils = require('persistent-breakpoints.utils')
local config = require('persistent-breakpoints.config')
local inmemory_bps = require('persistent-breakpoints.inmemory')
local breakpoints = require('dap.breakpoints')

local F = {}

F.breakpoints_changed_in_current_buffer = function()
	local current_buf_file_name = vim.api.nvim_buf_get_name(0)
	local current_buf_id = vim.api.nvim_get_current_buf()
	local current_buf_breakpoints = breakpoints.get()[current_buf_id]
	if #current_buf_file_name == 0 then
		return
	end
	-- Use relative path when filename is configured for portability
	local storage_key = utils.to_relative_path(current_buf_file_name)
	inmemory_bps.bps[storage_key] = current_buf_breakpoints
	inmemory_bps.changed = true
	local write_ok = utils.write_bps(utils.get_bps_path(),inmemory_bps.bps)
	inmemory_bps.changed = not write_ok
end

F.toggle_breakpoint = function ()
	require('dap').toggle_breakpoint();
	F.breakpoints_changed_in_current_buffer()
end

F.set_conditional_breakpoint = function ()
	require('dap').set_breakpoint(vim.fn.input('[Condition] > '));
	F.breakpoints_changed_in_current_buffer()
end

F.set_log_point = function()
	require("dap").set_breakpoint(nil, nil, vim.fn.input("[Message] > "))
	F.breakpoints_changed_in_current_buffer()
end

F.clear_all_breakpoints = function()
	require("dap").clear_breakpoints()
	inmemory_bps.bps = {}
	inmemory_bps.changed = true
	local write_ok = utils.write_bps(utils.get_bps_path(),inmemory_bps.bps)
	inmemory_bps.changed = not write_ok
end

F.store_breakpoints = function (clear)
	if clear == nil then
		local tmp_fbps = vim.deepcopy(inmemory_bps.bps)
		for bufid, bufbps in pairs(breakpoints.get()) do
			-- Use relative path when filename is configured for portability
			local storage_key = utils.to_relative_path(vim.api.nvim_buf_get_name(bufid))
			tmp_fbps[storage_key] = bufbps
		end
		utils.write_bps(utils.get_bps_path(),tmp_fbps)
	else
		vim.notify_once('The store_breakpoints function will not accept parameters in the future. If you want to clear all breakpoints, you should the use clear_all_breakpoints function.','WARN')
		if clear == true then
			F.clear_all_breakpoints()
		else
			F.store_breakpoints(nil)
		end
	end
end

F.load_breakpoints = function()
	local bbps = breakpoints.get()
	local fbps = inmemory_bps.bps
	local new_loaded_bufs = {}
	-- Find the new loaded buffer.
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		local file_name = vim.api.nvim_buf_get_name(buf)
		-- Convert to relative path for lookup when filename is configured
		local lookup_key = utils.to_relative_path(file_name)
		-- if bbps[buf] != nil => this file's breakpoints have been loaded.
		-- if vim.tbl_isempty(bps[lookup_key] or {}) => This file have no saved breakpoints.
		if bbps[buf] == nil and vim.tbl_isempty(fbps[lookup_key] or {}) == false then
			new_loaded_bufs[lookup_key] = buf
		end
	end
	for lookup_key, buf_id in pairs(new_loaded_bufs) do
		for _, bp in pairs(fbps[lookup_key]) do
			local line = bp.line
			local opts = {
				condition = bp.condition,
				log_message = bp.logMessage,
				hit_condition = bp.hitCondition
			}
			breakpoints.set(opts, buf_id, line)
			if config.on_load_breakpoint ~= nil then
				config.on_load_breakpoint(opts, buf_id, line)
			end
		end
	end
end

F.reload_breakpoints = function ()
	inmemory_bps.bps = utils.load_bps(utils.get_bps_path())
	inmemory_bps.changed = false
	breakpoints.clear()
	F.load_breakpoints()
end

--- Load all breakpoints from the JSON file for the current workspace.
--- This will open files (in background buffers) that have saved breakpoints
--- and set the breakpoints on them, even if they were not opened before.
F.load_all_breakpoints = function()
	-- Ensure inmemory_bps is loaded from file
	if inmemory_bps.bps == nil then
		inmemory_bps.bps = utils.load_bps(utils.get_bps_path())
		inmemory_bps.changed = false
	end
	local fbps = inmemory_bps.bps
	if not fbps or vim.tbl_isempty(fbps) then
		return
	end
	local loaded_count = 0
	local bp_count = 0
	for storage_key, bps in pairs(fbps) do
		if not vim.tbl_isempty(bps) then
			-- Convert relative path back to absolute path if needed
			local file_path = utils.to_absolute_path(storage_key)
			-- Check if file exists
			if vim.fn.filereadable(file_path) == 1 then
				-- Get or create buffer for the file (without opening in window)
				local buf_id = vim.fn.bufadd(file_path)
				-- Load the buffer content if not loaded yet
				if not vim.api.nvim_buf_is_loaded(buf_id) then
					vim.fn.bufload(buf_id)
				end
				-- Set breakpoints on the buffer
				for _, bp in pairs(bps) do
					local line = bp.line
					local opts = {
						condition = bp.condition,
						log_message = bp.logMessage,
						hit_condition = bp.hitCondition
					}
					breakpoints.set(opts, buf_id, line)
					if config.on_load_breakpoint ~= nil then
						config.on_load_breakpoint(opts, buf_id, line)
					end
					bp_count = bp_count + 1
				end
				loaded_count = loaded_count + 1
			end
		end
	end
	vim.notify(string.format('Loaded %d breakpoints from %d files', bp_count, loaded_count))
end

local perf_data = {}

local M = {}

for func_name, func_body in pairs(F) do
	M[func_name] = function ()
		if config.perf_record then
			local start_time = vim.fn.reltimefloat(vim.fn.reltime())
			func_body()
			local end_time = vim.fn.reltimefloat(vim.fn.reltime())
			perf_data[func_name] = end_time - start_time
		else
			func_body()
		end
	end
end

M.print_perf_data = function ()
	local result = ''
	for fn, fd in pairs(perf_data) do
		local ms = math.floor(fd*1e6+0.5)/1e3
		local str = fn .. ': ' .. tostring(ms) .. 'ms\n'
		result = result .. str
	end
	print(result)
end

return M
