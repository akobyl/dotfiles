-- See https://github.com/andrewberty/dotfiles/blob/main/wezterm/features.lua

local wezterm = require("wezterm")
local act = wezterm.action
local M = {}

M.globals_path = wezterm.config_dir .. "/globals.toml"

M.getLuaFromTOML = function()
	local file = assert(io.open(M.globals_path, "r"))
	local toml = file:read("a")
	file:close()
	-- wezterm.log_info("get lua from toml: " .. toml)
	return wezterm.serde.toml_decode(toml)
end

M.writeLuaToTOML = function(lua)
	local toml = wezterm.serde.toml_encode_pretty(lua)
	local file = assert(io.open(M.globals_path, "w"))
	file:write(toml)
	file:close()
end

M.switcher = function(window, pane, title, data, action)
	local choices = {}

	for key, _ in pairs(data) do
		table.insert(choices, { label = tostring(key) })
	end

	table.sort(choices, function(c1, c2)
		return c1.label < c2.label
	end)

	window:perform_action(act.InputSelector({ title = title, choices = choices, fuzzy = true, action = action }), pane)
end

M.theme_switcher = function(window, pane)
	local schemes = wezterm.get_builtin_color_schemes()
	local action = wezterm.action_callback(function(inner_window, _, _, label)
		if label then
			local overrides = inner_window:get_config_overrides() or {}
			overrides.color_scheme = label
			inner_window:set_config_overrides(overrides)
		end
	end)

	M.switcher(window, pane, "🎨 Pick a Theme!", schemes, action)
end

M.togglePadding = function()
	local lua = M.getLuaFromTOML()
	if lua.padding.top == 0 then
		lua.padding = { top = 20, bottom = 20, left = 20, right = 20 }
	else
		lua.padding = { top = 0, bottom = 0, left = 0, right = 0 }
	end
	M.writeLuaToTOML(lua)
end

M.is_dark = function()
	if wezterm.gui then
		return wezterm.gui.get_appearance():find("Dark")
	end
	return true
end

return M
