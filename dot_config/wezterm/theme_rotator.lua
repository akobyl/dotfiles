local wezterm = require("wezterm")

-- Create state to track current theme index
local M = {
	current_theme_idx = 1,
	themes = {
		"DanQing (base16)",
		"Ayu Light (Gogh)",
	},
}

function M.rotate_next()
	M.current_theme_idx = (M.current_theme_idx % #M.themes) + 1
	return M.themes[M.current_theme_idx]
end

function M.rotate_prev()
	M.current_theme_idx = M.current_theme_idx - 1
	if M.current_theme_idx < 1 then
		M.current_theme_idx = #M.themes
	end
	return M.themes[M.current_theme_idx]
end

-- Get current theme name
function M.get_current()
	return M.themes[M.current_theme_idx]
end

-- Add a new theme to the rotation
function M.add_theme(theme_name)
	table.insert(M.themes, theme_name)
end

-- Set up key bindings in your config
function M.setup_keybinds(config)
	config.keys = config.keys or {}

	-- Add keybindings for rotation
	table.insert(config.keys, {
		key = "n",
		mods = "CTRL|ALT",
		action = wezterm.action.EmitEvent("rotate-theme-next"),
	})

	table.insert(config.keys, {
		key = "p",
		mods = "CTRL|ALT",
		action = wezterm.action.EmitEvent("rotate-theme-prev"),
	})

	return config
end

return M
