-- Verified against tonybanters/oxwm fc4ada9ac4ee8e34ace203290a2b14d10e4671cc.
-- Lua actions are native OXWM operations; arrows mean stack/monitor order.
local mod = "Mod4"
local colors = {
  bg = "#1a1b26",
  fg = "#bbbbbb",
  accent = "#9fe3c4",
  workspace_highlight = "#d7ffe8",
  workspace_occupied = "#6ee7a0",
  dim = "#34324a",
  red = "#f7768e",
  blue = "#7aa2f7",
  lavender = "#bb9af7",
  cyan = "#0db9d7",
  orange = "#e0af68",
  green = "#9ece6a",
}
oxwm.set_terminal("st")
oxwm.set_modkey(mod)
oxwm.set_tags({ "1", "2", "3", "4", "5", "6", "7", "8", "9" })
-- Dwindle gives new windows recursive Fibonacci-style splits instead of the
-- traditional master/stack arrangement.
oxwm.set_layout("dwindle")
-- OXWM stores the selected layout per workspace; initialize every workspace
-- explicitly so each tag starts in dwindle mode on every monitor.
for i = 1, 9 do
  oxwm.set_tag_layout(i, "dwindle")
end
oxwm.set_attach_method("bottom")
oxwm.gaps.set_enabled(true)
oxwm.gaps.set_inner(8, 8)
oxwm.gaps.set_outer(8, 8)
oxwm.border.set_width(2)
oxwm.border.set_focused_color(colors.accent)
oxwm.border.set_unfocused_color(colors.dim)
oxwm.bar.set_font("JetBrainsMono Nerd Font:size=10")
oxwm.bar.set_scheme_normal(colors.fg, colors.bg, colors.dim)
oxwm.bar.set_scheme_occupied(colors.workspace_occupied, colors.bg, colors.dim)
oxwm.bar.set_scheme_selected(colors.accent, colors.bg, colors.workspace_highlight)
oxwm.bar.set_scheme_urgent(colors.red, colors.bg, colors.red)
oxwm.bar.set_hide_vacant_tags(false)

local blocks = {}
-- The X session detects the actual battery name once. Lua only reads sysfs;
-- the shell helper adds an estimate from the current discharge rate.
local battery = os.getenv("BLIX_BATTERY")
if battery and battery:match("^[%w_%-]+$") then
  local probe = io.open("/sys/class/power_supply/" .. battery .. "/type", "r")
  if probe then
    local present = probe:read("*l") == "Battery"
    probe:close()
    if present then
      table.insert(blocks, oxwm.bar.block.shell({
        format = "{}",
        command = "oxwm-battery",
        interval = 30,
        color = colors.green,
        underline = false,
      }))
    end
  end
end
table.insert(blocks, oxwm.bar.block.static({
  text = "│",
  interval = 999999999,
  color = colors.lavender,
  underline = false,
}))
table.insert(blocks, oxwm.bar.block.ram({
  format = "Ram: {used}/{total} GB",
  interval = 5,
  color = colors.blue,
  underline = true,
}))
table.insert(blocks, oxwm.bar.block.static({
  text = "│",
  interval = 999999999,
  color = colors.lavender,
  underline = false,
}))
table.insert(blocks, oxwm.bar.block.shell({
  format = "CPU: {}%",
  command = "oxwm-cpu",
  interval = 5,
  color = colors.orange,
  underline = true,
}))
table.insert(blocks, oxwm.bar.block.static({
  text = "│",
  interval = 999999999,
  color = colors.lavender,
  underline = false,
}))
table.insert(blocks, oxwm.bar.block.datetime({
  format = "{}",
  date_format = "%a, %b %d - %H:%M",
  interval = 60,
  color = colors.cyan,
  underline = true,
}))
oxwm.bar.set_blocks(blocks)

-- All OXWM bindings live in this file. OXWM reload/restart is intentionally
-- not bound to any key; edit this file and restart OXWM from a shell when
-- changing bindings.
oxwm.key.bind({ mod }, "Space", oxwm.spawn("dmenu_run"))
oxwm.key.bind({ mod }, "D", oxwm.spawn("dmenu_run"))
oxwm.key.bind({ mod }, "F", oxwm.spawn("xfe"))
oxwm.key.bind({ mod }, "B", oxwm.spawn("firefox"))
oxwm.key.bind({ mod }, "P", oxwm.client.toggle_floating())
oxwm.key.bind({ mod }, "C", oxwm.layout.set("tiling"))
oxwm.key.bind({ mod }, "R", oxwm.layout.set("dwindle"))
oxwm.key.bind({ mod, "Shift" }, "F", oxwm.client.toggle_fullscreen())
-- Previous numbered tag, not a most-recently-used tag toggle.
oxwm.key.bind({ mod }, "Tab", oxwm.tag.view_previous())
for i = 1, 9 do
  oxwm.key.bind({ mod }, tostring(i), oxwm.tag.view(i - 1))
  oxwm.key.bind({ mod, "Shift" }, tostring(i), oxwm.tag.move_to(i - 1))
end
for _, key in ipairs({ "Left", "Up" }) do
  oxwm.key.bind({ mod }, key, oxwm.client.focus_stack(-1))
  oxwm.key.bind({ mod, "Shift" }, key, oxwm.client.move_stack(-1))
  oxwm.key.bind({ mod, "Control" }, key, oxwm.monitor.focus(-1))
  oxwm.key.bind({ mod, "Control", "Shift" }, key, oxwm.monitor.tag(-1))
end
for _, key in ipairs({ "Right", "Down" }) do
  oxwm.key.bind({ mod }, key, oxwm.client.focus_stack(1))
  oxwm.key.bind({ mod, "Shift" }, key, oxwm.client.move_stack(1))
  oxwm.key.bind({ mod, "Control" }, key, oxwm.monitor.focus(1))
  oxwm.key.bind({ mod, "Control", "Shift" }, key, oxwm.monitor.tag(1))
end
oxwm.key.bind({ mod }, "minus", oxwm.set_master_factor(-50))
oxwm.key.bind({ mod }, "equal", oxwm.set_master_factor(50))
oxwm.key.bind({ mod, "Shift" }, "minus", oxwm.inc_num_master(-1))
oxwm.key.bind({ mod, "Shift" }, "equal", oxwm.inc_num_master(1))
oxwm.key.bind({ mod }, "N", oxwm.layout.cycle())
-- The control menu sends this native quit binding after confirmation. OXWM
-- currently has no external quit IPC. No window geometry is simulated.
oxwm.key.bind({ mod, "Shift" }, "Q", oxwm.quit())
oxwm.key.bind({ mod, "Shift" }, "S", oxwm.spawn("screenshot-region"))
oxwm.key.bind({}, "Print", oxwm.spawn("screenshot-region --full"))
oxwm.key.bind({ "Mod1" }, "Print", oxwm.spawn("screenshot-region --window"))
oxwm.key.bind({ mod }, "V", oxwm.spawn("clipboard-history"))
oxwm.key.bind({ mod }, "L", oxwm.spawn("blix-lock"))
oxwm.key.bind({ mod, "Shift" }, "Space", oxwm.spawn("control-menu"))
oxwm.key.bind({}, "XF86AudioRaiseVolume", oxwm.spawn("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"))
oxwm.key.bind({}, "XF86AudioLowerVolume", oxwm.spawn("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
oxwm.key.bind({}, "XF86AudioMute", oxwm.spawn("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
oxwm.key.bind({}, "XF86AudioMicMute", oxwm.spawn("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))
oxwm.key.bind({}, "XF86AudioPlay", oxwm.spawn("playerctl play-pause"))
oxwm.key.bind({}, "XF86AudioNext", oxwm.spawn("playerctl next"))
oxwm.key.bind({}, "XF86AudioPrev", oxwm.spawn("playerctl previous"))
oxwm.key.bind({}, "XF86MonBrightnessUp", oxwm.spawn("blix-brightness up"))
oxwm.key.bind({}, "XF86MonBrightnessDown", oxwm.spawn("blix-brightness down"))

-- Core terminal/window bindings.
oxwm.key.bind({ mod }, "Return", oxwm.spawn_terminal())
oxwm.key.bind({ mod }, "Q", oxwm.client.kill())
