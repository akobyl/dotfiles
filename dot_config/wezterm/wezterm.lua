local wezterm = require("wezterm")
local theme_rotator = require("theme_rotator")
local features = require("features")
local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")
local weather = wezterm.plugin.require("https://github.com/akobyl/wez-weather")
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

-- Tab title: user rename takes priority, then foreground process, then pane title
local function tab_title(tab)
    if tab.tab_title and #tab.tab_title > 0 then
        return " " .. tab.tab_title .. " "
    end
    local proc = tab.active_pane.foreground_process_name
    if proc and proc ~= "" then
        proc = proc:match("([^/\\]+)$") or proc
        if proc ~= "wslhost.exe" then
            return " " .. proc .. " "
        end
    end
    return " " .. (tab.active_pane.title or "") .. " "
end

-- Right-status custom components (cwd is tab-only in tabline.wez, so use window functions)
local function active_cwd(window)
    local cwd = get_cwd(window:active_pane())
    return cwd or ""
end

local function git_branch(window)
    local cwd = get_cwd(window:active_pane())
    if not cwd then return "" end
    local ok, stdout = wezterm.run_child_process({ "git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD" })
    if not ok or not stdout then return "" end
    local branch = stdout:gsub("%s+$", "")
    if branch == "" or branch == "HEAD" then return "" end
    return wezterm.nerdfonts.dev_git_branch .. "  " .. branch
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

config.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }

config.wsl_domains = {
    {
        name = "WSL:Ubuntu-22.04",
        distribution = "Ubuntu-22.04",
        username = "andy",
        default_cwd = "~",
    },
}

-- local_config.lua is NOT chezmoi-managed and lives only on this machine
-- (alongside wezterm.lua), so a real location never ends up in this public
-- dotfiles repo. Create it with: return { location = "your-zip-or-city" }
local ok, local_config = pcall(require, "local_config")
local weather_location = (ok and local_config and local_config.location) or "New York"

weather.setup({
    location = weather_location,
    units = "fahrenheit",
    update_interval = 600,
})

tabline.setup({
    sections = {
        tabline_a = { "mode" },
        tabline_b = { "workspace" },
        tabline_c = { " " },
        tab_active = { "index", tab_title, { "zoomed", padding = 0 } },
        tab_inactive = { "index", tab_title },
        tabline_x = { git_branch },
        tabline_y = { active_cwd },
        tabline_z = { weather.component, "domain" },
    },
})
tabline.apply_to_config(config)

wezterm.on("toggle-tabbar", function(window, _)
    local overrides = window:get_config_overrides() or {}
    if overrides.enable_tab_bar == false then
        overrides.enable_tab_bar = true
    else
        overrides.enable_tab_bar = false
    end
    window:set_config_overrides(overrides)
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

    -- Fuzzy theme picker
    {
        key = "s",
        mods = "LEADER",
        action = wezterm.action_callback(features.theme_switcher),
    },

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

    -- Close current pane
    {
        key = "w",
        mods = "LEADER",
        action = act.CloseCurrentPane({ confirm = true }),
    },

    -- Rename current tab (Ctrl+Shift+R is taken by reload-config)
    {
        key = "r",
        mods = "LEADER",
        action = wezterm.action_callback(function(window, pane)
            window:perform_action(
                act.PromptInputLine({
                    description = "Tab name:",
                    action = wezterm.action_callback(function(inner_window, _, line)
                        if line then
                            inner_window:active_tab():set_title(line)
                        end
                    end),
                }),
                pane
            )
        end),
    },
}

return config
