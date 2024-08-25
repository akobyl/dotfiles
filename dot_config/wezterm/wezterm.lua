local wezterm = require("wezterm")
local config = wezterm.config_builder()
local act = wezterm.action
local features = require("features")
local G = features.getLuaFromTOML()
local docker = require("docker")

config.exec_domains = docker.compute_exec_domains()

-- if features.is_dark() then
-- 	config.color_scheme = "Tokyo Night"
-- 	config.window_background_opacity = 0.85
-- else
-- 	--config.color_scheme = "Tokyo Night Day"
-- 	--config.color_scheme = "Ashes (light) (terminal.sexy)"
-- 	config.color_scheme = "Ashes (dark) (terminal.sexy)"
--
-- 	config.window_background_opacity = 0.95
-- end
-- config.visual_bell = {
-- 	fade_in_function = "EaseIn",
-- 	fade_in_duration_ms = 0,
-- 	fade_out_function = "EaseOut",
-- 	fade_out_duration_ms = 0,
-- }
local scheme = G.colorscheme or "Tokyo Night"
config.color_scheme = scheme

config.font = wezterm.font("FiraCode Nerd Font")
config.font_size = 17

config.window_background_opacity = 0.85
config.macos_window_background_blur = 20
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"

config.window_frame = {
	font = wezterm.font({ family = "Cousine Nerd Font Propo", weight = "Bold" }),
	font_size = 13,
}

config.window_padding = G.padding

local DOMAIN_TO_SCHEME = {
	["SSHMUX:abihail"] = "Earthsong (Gogh)",
	["SSHMUX:pcontrolak"] = "Brush Trees Dark (base16)",
}

wezterm.on("update-status", function(window, pane, _)
	local domain = pane:get_domain_name()

	-- show the domain name in the right status area to aid in debugging/understanding
	-- window:set_right_status(domain)

	-- solid arrow
	local utf8 = require("utf8")
	local SOLID_LEFT_ARROW = utf8.char(0xe0b2)

	-- Grab the current window's configuration, and from it the
	-- palette (this is the combination of your chosen colour scheme
	-- including any overrides).
	local color_scheme = window:effective_config().resolved_palette
	local bg = color_scheme.background
	local fg = color_scheme.foreground

	window:set_right_status(wezterm.format({
		{ Background = { Color = "none" } },
		{ Foreground = { Color = bg } },
		{ Text = SOLID_LEFT_ARROW },
		{ Background = { Color = bg } },
		{ Foreground = { Color = fg } },
		{ Text = " " .. domain .. " " },
	}))

	local overrides = window:get_config_overrides() or {}
	-- resolve the scheme for the domain. If there is no mapping, then the overridden
	-- scheme is cleared and your default colors will be used
	overrides.color_scheme = DOMAIN_TO_SCHEME[domain]
	window:set_config_overrides(overrides)
end)

wezterm.on("toggle-tabbar", function(window, _)
	local overrides = window:get_config_overrides() or {}
	if overrides.enable_tab_bar == false then
		wezterm.log_info("tab bar shown")
		overrides.enable_tab_bar = true
	else
		wezterm.log_info("tab bar hidden")
		overrides.enable_tab_bar = false
	end
	window:set_config_overrides(overrides)
end)

-- Projects
--
local function project_dirs()
	local project_dir = wezterm.home_dir .. "/aescape"
	local projects = { wezterm.home_dir }

	for _, dir in ipairs(wezterm.glob(project_dir .. "/*")) do
		table.insert(projects, dir)
	end

	-- wezterm.log_info(projects)
	return projects
end

local function choose_project()
	local choices = {}
	for _, value in ipairs(project_dirs()) do
		table.insert(choices, { label = value })
	end

	return wezterm.action.InputSelector({
		title = "Projects",
		choices = choices,
		fuzzy = true,
		action = wezterm.action_callback(function(child_window, child_pane, id, label)
			-- "label" may be empty if nothing was selected. Don't bother doing anything
			-- when that happens.
			if not label then
				return
			end

			-- The SwitchToWorkspace action will switch us to a workspace if it already exists,
			-- otherwise it will create it for us.
			child_window:perform_action(
				wezterm.action.SwitchToWorkspace({
					-- We'll give our new workspace a nice name, like the last path segment
					-- of the directory we're opening up.
					name = label:match("([^/]+)$"),
					-- Here's the meat. We'll spawn a new terminal with the current working
					-- directory set to the directory that was picked.
					spawn = { cwd = label },
				}),
				child_pane
			)
		end),
	})
end

-- Keybindings
--
config.leader = { key = "/", mods = "CTRL", timeout_milliseconds = 1000 }
config.keys = {
	{ key = "T", mods = "CTRL|SHIFT", action = act.EmitEvent("toggle-tabbar") },

	{ key = "p", mods = "LEADER", action = choose_project() },

	{ key = "f", mods = "LEADER", action = wezterm.action.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },

	{ key = "t", mods = "LEADER", action = wezterm.action_callback(features.theme_switcher) },

	{ key = "x", mods = "LEADER", action = wezterm.action_callback(features.togglePadding) },
}

return config

-- Extras...
-- config.color_scheme = "LiquidCarbonTransparent"
-- config.color_scheme = "Dracula+"
-- config.color_scheme = "DoomOne"
-- config.color_scheme = "Tokyo Night"
-- config.color_scheme = "Belaforte Day"
-- config.font = wezterm.font("MesloLGM Nerd Font")
-- config.font = wezterm.font("SauceCodePro Nerd Font Mono")
-- config.font = wezterm.font("NotoMono Nerd Font")
