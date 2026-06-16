local wezterm = require("wezterm")
local theme_rotator = require("theme_rotator")
local features = require("features")
local act = wezterm.action

local config = wezterm.config_builder()

-- ─── helpers ─────────────────────────────────────────────────────────────────

-- CWD from a live Pane object (requires OSC 7 from the shell).
-- Rejects Windows-style paths that appear before OSC 7 fires.
local function get_cwd(pane)
    local uri = pane:get_current_working_dir()
    if uri then
        local path = uri.file_path
        if path and not path:match("^/%a:/") then return path end
    end
    return nil
end

-- CWD from a PaneInformation table (handed to format-tab-title).
local function cwd_from_pane_info(pane_info)
    local uri = pane_info and pane_info.current_working_dir
    if uri then
        local path = uri.file_path
        if path and not path:match("^/%a:/") then return path end
    end
    return nil
end

-- Tab label: user rename > foreground process > pane title.
local function tab_title(tab)
    if tab.tab_title and #tab.tab_title > 0 then return tab.tab_title end
    local proc = tab.active_pane.foreground_process_name
    if proc and proc ~= "" then
        proc = proc:match("([^/\\]+)$") or proc
        if proc ~= "wslhost.exe" then return proc end
    end
    return tab.active_pane.title or ""
end

-- ─── tab colour palette ───────────────────────────────────────────────────────

local TAB_COLORS = {
    "#7c3aed", "#dc2626", "#ea580c", "#0284c7",
    "#16a34a", "#ca8a04", "#db2777", "#0d9488",
    "#4f46e5", "#65a30d", "#9333ea", "#0891b2",
}

local function hash_string(str)
    local h = 5381
    for i = 1, #str do h = (h * 33 + str:byte(i)) % 2147483647 end
    return h
end

local function color_for_path(path)
    if not path or path == "" then return TAB_COLORS[1] end
    return TAB_COLORS[(hash_string(path) % #TAB_COLORS) + 1]
end

-- ─── project picker ───────────────────────────────────────────────────────────

local function project_dirs()
    local dirs = {}
    for _, base in ipairs({ "/home/andy/dev", "/home/andy/dev/gamez" }) do
        local ok, out = pcall(function()
            local h = io.popen("ls -1 " .. base .. " 2>/dev/null")
            local r = h:read("*a"); h:close(); return r
        end)
        if ok and out then
            for entry in out:gmatch("[^\r\n]+") do
                if entry ~= "" then
                    local full = base .. "/" .. entry
                    local dc = io.popen("test -d '" .. full .. "' && echo dir")
                    local is_dir = dc:read("*a"):match("dir"); dc:close()
                    if is_dir then table.insert(dirs, full) end
                end
            end
        end
    end
    return dirs
end

local function choose_project()
    local choices = {}
    for _, v in ipairs(project_dirs()) do table.insert(choices, { label = v }) end
    return wezterm.action.InputSelector({
        title = "Projects", choices = choices, fuzzy = true,
        action = wezterm.action_callback(function(win, pane, _, label)
            if not label then return end
            win:perform_action(wezterm.action.SwitchToWorkspace({
                name = label:match("([^/]+)$"), spawn = { cwd = label },
            }), pane)
        end),
    })
end

-- ─── inline weather ───────────────────────────────────────────────────────────
-- No plugin system used — avoids any plugin-load errors that would silently
-- roll back the whole config to the previous version.

local WEATHER_INTERVAL = 600   -- seconds between API refreshes

local wx = { lat = nil, lon = nil, geocode_failed = false, text = "", last_fetch = 0 }

local function urlencode(s)
    return (s:gsub("[^%w%-%_%.%~]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

local function http_json(url)
    local ok, result = pcall(function()
        local ok2, out = wezterm.run_child_process({ "curl", "-s", "--max-time", "5", url })
        if not ok2 or not out or out == "" then return nil end
        local ok3, data = pcall(wezterm.json_parse, out)
        return ok3 and data or nil
    end)
    return ok and result or nil
end

local function wx_geocode(location)
    -- Accept explicit "lat,lon"
    local lat, lon = location:match("^(-?%d+%.?%d*),(-?%d+%.?%d*)$")
    if lat and lon then return tonumber(lat), tonumber(lon) end
    -- US zip code
    if location:match("^%d%d%d%d%d$") then
        local d = http_json("https://api.zippopotam.us/us/" .. location)
        local p = d and d.places and d.places[1]
        if p then return tonumber(p["latitude"]), tonumber(p["longitude"]) end
        return nil, nil
    end
    -- City name
    local d = http_json("https://geocoding-api.open-meteo.com/v1/search?count=1&name=" .. urlencode(location))
    local r = d and d.results and d.results[1]
    if r then return r.latitude, r.longitude end
    return nil, nil
end

local function wx_refresh(location)
    if not wx.lat then
        if wx.geocode_failed then return end
        local lat, lon = wx_geocode(location)
        if lat and lon then
            wx.lat, wx.lon = lat, lon
        else
            wx.geocode_failed = true
            return
        end
    end
    local url = string.format(
        "https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s"
        .. "&current=temperature_2m,weather_code&temperature_unit=fahrenheit",
        wx.lat, wx.lon)
    local d = http_json(url)
    if d and d.current and d.current.temperature_2m then
        wx.text = string.format("%.0f°F", d.current.temperature_2m)
    end
end

local function weather_text(location)
    local now = os.time()
    if now - wx.last_fetch >= WEATHER_INTERVAL then
        wx.last_fetch = now
        pcall(wx_refresh, location)
    end
    return wx.text
end

-- ─── font / window ────────────────────────────────────────────────────────────

config.font      = wezterm.font("FiraCode Nerd Font")
config.font_size = 13
config.harfbuzz_features = { "liga=1", "zero" }

config.default_domain = "WSL:Ubuntu-22.04"
config.default_prog   = { "wsl" }
config.default_cwd    = "\\\\wsl.localhost\\Ubuntu-22.04\\home\\andy"
config.allow_win32_input_mode = false
config.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }

config.wsl_domains = {{
    name = "WSL:Ubuntu-22.04", distribution = "Ubuntu-22.04",
    username = "andy", default_cwd = "~",
}}

-- ─── tab bar ─────────────────────────────────────────────────────────────────

config.use_fancy_tab_bar         = false
config.tab_bar_at_bottom         = true
config.tab_max_width             = 32
config.show_new_tab_button_in_tab_bar = true
config.status_update_interval    = 30000   -- ms; right-status refresh rate

config.colors = {
    tab_bar = {
        background    = "#1e1e1e",
        new_tab       = { bg_color = "#1e1e1e", fg_color = "#6b6b6b" },
        new_tab_hover = { bg_color = "#333333", fg_color = "#ffffff" },
        inactive_tab_edge = "#1e1e1e",
    },
}

wezterm.on("format-tab-title", function(tab, tabs, panes, conf, hover, max_width)
    local cwd = cwd_from_pane_info(tab.active_pane)
    local bg  = color_for_path(cwd or tostring(tab.tab_id))
    local title = tab_title(tab)
    local text  = string.format(" %d: %s ", tab.tab_index + 1, title)
    if #text > max_width then text = text:sub(1, max_width - 1) .. "… " end
    return {
        { Background = { Color = bg } },
        { Foreground = { Color = "#ffffff" } },
        { Attribute = { Intensity = tab.is_active and "Bold" or "Normal" } },
        { Text = text },
    }
end)

-- ─── right status: weather | git branch | cwd ────────────────────────────────

-- local_config.lua lives only on this machine (not chezmoi-managed, never
-- committed). Create it with: return { location = "your-zip-or-city" }
local ok_lc, local_config = pcall(require, "local_config")
local weather_location = (ok_lc and local_config and local_config.location) or "New York"

wezterm.on("update-status", function(window, pane)
    local parts = {}

    local w = weather_text(weather_location)
    if w ~= "" then table.insert(parts, w) end

    local cwd = get_cwd(pane)
    if cwd then
        local ok, out = wezterm.run_child_process({ "git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD" })
        if ok and out then
            local branch = out:gsub("%s+$", "")
            if branch ~= "" and branch ~= "HEAD" then
                table.insert(parts, branch)
            end
        end
        table.insert(parts, cwd)
    end

    window:set_right_status(wezterm.format({
        { Foreground = { Color = "#a0a0a0" } },
        { Text = "  " .. table.concat(parts, " | ") .. "  " },
    }))
end)

-- ─── events ──────────────────────────────────────────────────────────────────

wezterm.on("toggle-tabbar", function(window, _)
    local ov = window:get_config_overrides() or {}
    ov.enable_tab_bar = (ov.enable_tab_bar == false) and true or false
    window:set_config_overrides(ov)
end)

wezterm.on("rotate-theme-next", function(window, _)
    local ov = window:get_config_overrides() or {}
    ov.color_scheme = theme_rotator.rotate_next()
    window:set_config_overrides(ov)
end)

-- ─── keys ────────────────────────────────────────────────────────────────────

config.leader = { key = "/", mods = "CTRL", timeout_milliseconds = 1000 }
config.keys = {
    { key = "t", mods = "LEADER",   action = act.EmitEvent("toggle-tabbar") },
    { key = "T", mods = "CTRL|ALT", action = act.EmitEvent("toggle-tabbar") },
    { key = "n", mods = "CTRL|ALT", action = act.EmitEvent("rotate-theme-next") },
    { key = "s", mods = "LEADER",   action = wezterm.action_callback(features.theme_switcher) },
    { key = "p", mods = "LEADER",   action = choose_project() },
    { key = "f", mods = "LEADER",   action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },
    {
        key = "t", mods = "CTRL|SHIFT",
        action = wezterm.action_callback(function(win, pane)
            local cwd = get_cwd(pane)
            win:perform_action(act.SpawnCommandInNewTab(cwd and { cwd = cwd } or {}), pane)
        end),
    },
    {
        key = "d", mods = "CTRL|SHIFT",
        action = wezterm.action_callback(function(win, pane)
            local cwd = get_cwd(pane)
            local split = { direction = "Right" }
            if cwd then split.command = { cwd = cwd } end
            win:perform_action(act.SplitPane(split), pane)
        end),
    },
    { key = "w", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) },
    {
        key = "r", mods = "LEADER",
        action = wezterm.action_callback(function(win, pane)
            win:perform_action(act.PromptInputLine({
                description = "Tab name:",
                action = wezterm.action_callback(function(inner_win, _, line)
                    if line then inner_win:active_tab():set_title(line) end
                end),
            }), pane)
        end),
    },
}

return config
