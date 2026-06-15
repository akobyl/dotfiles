local wezterm = require("wezterm")
local theme_rotator = require("theme_rotator")
local act = wezterm.action

local config = wezterm.config_builder()

-- Returns the current working directory for a pane (requires OSC 7 in shell).
-- Rejects Windows-style paths (e.g. /C:/Users/Andy) that WSL cannot chdir to;
-- those appear when OSC 7 hasn't fired yet and WezTerm falls back to the Win CWD.
local function get_cwd(pane)
    local cwd_uri = pane:get_current_working_dir()
    if cwd_uri then
        local path = cwd_uri.file_path
        if path and not path:match("^/%a:/") then
            return path
        end
    end
    return nil
end

-- Project directories for WSL
local function project_dirs()
    local dirs = {}
    local base_dirs = { "/home/andy/dev", "/home/andy/dev/gamez" }

    for _, base_dir in ipairs(base_dirs) do
        local success, entries = pcall(function()
            local handle = io.popen("ls -1 " .. base_dir .. " 2>/dev/null")
            local result = handle:read("*a")
            handle:close()
            return result
        end)

        if success and entries then
            for entry in entries:gmatch("[^\r\n]+") do
                if entry ~= "" then
                    local full_path = base_dir .. "/" .. entry
                    local dir_check = io.popen("test -d '" .. full_path .. "' && echo 'dir'")
                    local is_dir = dir_check:read("*a"):match("dir")
                    dir_check:close()
                    if is_dir then
                        table.insert(dirs, full_path)
                    end
                end
            end
        end
    end

    return dirs
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
            if not label then return end
            child_window:perform_action(
                wezterm.action.SwitchToWorkspace({
                    name = label:match("([^/]+)$"),
                    spawn = { cwd = label },
                }),
                child_pane
            )
        end),
    })
end

config.font = wezterm.font("FiraCode Nerd Font")
config.font_size = 13
config.harfbuzz_features = { "liga=1", "zero" }

config.default_domain = "WSL:Ubuntu-22.04"
config.default_prog = { "wsl" }
config.default_cwd = "\\\\wsl.localhost\\Ubuntu-22.04\\home\\andy"
config.allow_win32_input_mode = false
config.hide_tab_bar_if_only_one_tab = true

config.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }

config.wsl_domains = {
    {
        name = "WSL:Ubuntu-22.04",
        distribution = "Ubuntu-22.04",
        username = "andy",
        default_cwd = "~",
    },
}

wezterm.on("toggle-tabbar", function(window, _)
    local overrides = window:get_config_overrides() or {}
    if overrides.enable_tab_bar == false then
        overrides.enable_tab_bar = true
    else
        overrides.enable_tab_bar = false
    end
    window:set_config_overrides(overrides)
end)

wezterm.on("update-status", function(window, pane)
    window:set_right_status(pane:get_domain_name())
end)

wezterm.on("rotate-theme-next", function(window, _)
    local overrides = window:get_config_overrides() or {}
    overrides.color_scheme = theme_rotator.rotate_next()
    window:set_config_overrides(overrides)
end)

config.leader = { key = "/", mods = "CTRL", timeout_milliseconds = 1000 }
config.keys = {
    -- Tab bar
    { key = "t", mods = "LEADER",   action = act.EmitEvent("toggle-tabbar") },
    { key = "T", mods = "CTRL|ALT", action = act.EmitEvent("toggle-tabbar") },

    -- Theme rotation
    { key = "n", mods = "CTRL|ALT", action = act.EmitEvent("rotate-theme-next") },

    -- Project switcher
    { key = "p", mods = "LEADER", action = choose_project() },
    { key = "f", mods = "LEADER", action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },

    -- New tab inheriting cwd (overrides default CTRL+SHIFT+T)
    {
        key = "t",
        mods = "CTRL|SHIFT",
        action = wezterm.action_callback(function(window, pane)
            local cwd = get_cwd(pane)
            local cmd = cwd and { cwd = cwd } or {}
            window:perform_action(act.SpawnCommandInNewTab(cmd), pane)
        end),
    },

    -- Vertical split (side-by-side) inheriting cwd
    {
        key = "d",
        mods = "CTRL|SHIFT",
        action = wezterm.action_callback(function(window, pane)
            local cwd = get_cwd(pane)
            local split = { direction = "Right" }
            if cwd then split.command = { cwd = cwd } end
            window:perform_action(act.SplitPane(split), pane)
        end),
    },
}

return config
