local config = {}

config = {
	save_dir = vim.fn.stdpath('data') .. '/nvim_checkpoints',
	load_breakpoints_event = nil,
	perf_record = false,
	on_load_breakpoint = nil,
	always_reload = false,
	-- Fixed filename for breakpoints (without .json extension)
	-- If set, uses this filename instead of absolute path
	-- Example: 'breakpoints' will create 'breakpoints.json'
	-- Useful for projects that may be moved between directories
	filename = nil,
}

return config

