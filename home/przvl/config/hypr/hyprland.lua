-- Blix / Hyprland 0.56. Keep OXWM's layout, palette and keyboard vocabulary.
local internal = "@internalOutput@"
hl.monitor({ output = internal, mode = "preferred", position = "0x0", scale = @internalScale@ })
-- The fallback includes dynamically named dock/MST outputs. Exact internal
-- output rules take precedence, so new external outputs mirror automatically.
hl.monitor({ output = "", mode = "@mirrorMode@", position = "auto", scale = 1, mirror = internal })

-- Match the mirror source's aspect ratio to the external desktop while docked.
-- A native 16:10 source otherwise leaves black side bars on a 16:9 mirror.
local function update_mirror_source()
    local docked = false
    for _, monitor in ipairs(hl.get_monitors()) do
        if monitor.name ~= internal or #monitor.mirrors > 0 then
            docked = true
            break
        end
    end
    hl.monitor({
        output = internal, position = "0x0",
        mode = docked and "@mirrorMode@" or "preferred",
        scale = docked and 1 or @internalScale@,
    })
end
-- Defer until startup/reload or hotplug has finished updating the output list.
local function schedule_mirror_update()
    -- Config verification has no outputs or running event loop.
    if #hl.get_monitors() == 0 then return end
    hl.timer(update_mirror_source, { timeout = 100, type = "oneshot" })
end
hl.on("hyprland.start", schedule_mirror_update)
hl.on("config.reloaded", schedule_mirror_update)
hl.on("monitor.added", schedule_mirror_update)
hl.on("monitor.removed", schedule_mirror_update)

hl.config({
    general = {
        layout = "dwindle", gaps_in = 0, gaps_out = 0, border_size = 2,
        col = { active_border = "rgb(9fe3c4)", inactive_border = "rgb(34324a)" },
        resize_on_border = true,
    },
    decoration = {
        rounding = 0, active_opacity = 1, inactive_opacity = 1,
        blur = { enabled = false }, shadow = { enabled = false },
    },
    animations = { enabled = false },
    -- Keep compositor shortcuts available even when an app requests inhibition.
    binds = { disable_keybind_grabbing = true },
    dwindle = { preserve_split = true, force_split = 2 },
    master = { new_status = "slave" },
    input = {
        kb_layout = "us", repeat_delay = 200, repeat_rate = 50,
        natural_scroll = true,
        touchpad = {
            natural_scroll = true, tap_to_click = true, tap_button_map = "lrm",
            clickfinger_behavior = true, disable_while_typing = true,
        },
    },
    misc = {
        disable_hyprland_logo = true, disable_splash_rendering = true,
        force_default_wallpaper = 0,
        mouse_move_enables_dpms = true, key_press_enables_dpms = true,
    },
    debug = { vfr = true },
    ecosystem = { no_donation_nag = true, no_update_news = true },
})
-- Match the external keyboard quirk from blix-hardware-hotplug.
hl.device({ name = "gaming-keyboard", kb_options = "altwin:swap_alt_win" })
hl.device({ name = "gaming-keyboard-1", kb_options = "altwin:swap_alt_win" })
-- A TrackPoint is not a naturally scrolling mouse.
hl.device({ name = "tpps/2-ibm-trackpoint", natural_scroll = false })
hl.env("XCURSOR_THEME", "WhiteSur-cursors")
hl.env("XCURSOR_SIZE", "32")
hl.env("TERMINAL", "foot")

hl.on("hyprland.start", function() hl.exec_cmd("@session@") end)

-- Binding changes belong in this config; do not add unbind/toggle submaps.
local function spawn(key, cmd, flags)
    hl.bind(key, hl.dsp.exec_cmd(cmd), flags or {})
end
spawn("SUPER + Return", "@foot@")
spawn("SUPER + Space", "@fuzzel@")
spawn("SUPER + D", "@fuzzel@")
spawn("SUPER + F", "@xfe@")
spawn("SUPER + B", "@firefox@")
spawn("SUPER + V", "@clipboard@")
spawn("SUPER + L", "@lock@")
spawn("SUPER + SHIFT + Space", "@control@")
spawn("SUPER + SHIFT + S", "@screenshot@")
spawn("Print", "@screenshot@ --full")
spawn("ALT + Print", "@screenshot@ --window")
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + SHIFT + Q", hl.dsp.exit())
hl.bind("SUPER + P", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind("SUPER + Tab", function()
    local ws = hl.get_active_workspace()
    if ws then hl.dispatch(hl.dsp.focus({ workspace = ((ws.id - 2) % 9) + 1 })) end
end)
for i = 1, 9 do
    hl.workspace_rule({ workspace = tostring(i), persistent = true })
    hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = i, follow = false }))
end
for _, key in ipairs({ "Left", "Up", "Right", "Down" }) do
    local next_window = key == "Right" or key == "Down"
    hl.bind("SUPER + " .. key, hl.dsp.window.cycle_next({ next = next_window }))
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.swap(next_window and { next = true } or { prev = true }))
    hl.bind("SUPER + CTRL + " .. key, hl.dsp.focus({ monitor = next_window and "+1" or "-1" }))
    hl.bind("SUPER + CTRL + SHIFT + " .. key,
        hl.dsp.window.move({ monitor = next_window and "+1" or "-1" }))
end
local function set_layout(name)
    local ws = hl.get_active_workspace()
    if ws then hl.workspace_rule({ workspace = tostring(ws.id), layout = name }) end
end
hl.bind("SUPER + C", function() set_layout("master") end)
hl.bind("SUPER + R", function() set_layout("dwindle") end)
hl.bind("SUPER + N", function()
    local ws = hl.get_active_workspace()
    if ws then set_layout(ws.tiled_layout == "master" and "dwindle" or "master") end
end)
local function adjust_ratio(delta)
    local ws = hl.get_active_workspace()
    local command = ws and ws.tiled_layout == "master" and "mfact " or "splitratio "
    hl.dispatch(hl.dsp.layout(command .. delta))
end
hl.bind("SUPER + minus", function() adjust_ratio("-0.05") end)
hl.bind("SUPER + equal", function() adjust_ratio("+0.05") end)
hl.bind("SUPER + SHIFT + minus", hl.dsp.layout("removemaster"))
hl.bind("SUPER + SHIFT + equal", hl.dsp.layout("addmaster"))
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

local repeat_locked = { locked = true, repeating = true }
spawn("XF86AudioRaiseVolume", "@wpctl@ set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+", repeat_locked)
spawn("XF86AudioLowerVolume", "@wpctl@ set-volume @DEFAULT_AUDIO_SINK@ 5%-", repeat_locked)
spawn("XF86AudioMute", "@wpctl@ set-mute @DEFAULT_AUDIO_SINK@ toggle", { locked = true })
spawn("XF86AudioMicMute", "@wpctl@ set-mute @DEFAULT_AUDIO_SOURCE@ toggle", { locked = true })
spawn("XF86AudioPlay", "@playerctl@ play-pause", { locked = true })
spawn("XF86AudioNext", "@playerctl@ next", { locked = true })
spawn("XF86AudioPrev", "@playerctl@ previous", { locked = true })
spawn("XF86MonBrightnessUp", "@brightnessctl@ --class=backlight set 5%+", repeat_locked)
spawn("XF86MonBrightnessDown", "@brightnessctl@ --class=backlight --min-value=1 set 5%-", repeat_locked)
