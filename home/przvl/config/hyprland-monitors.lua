-- Prefer an external source so its native aspect ratio fills the external panel.
local primary = "@primary-output@"
local previous_outputs = nil
local source = primary
local pending = false

local function apply_monitors()
  local outputs = {}
  for _, monitor in ipairs(hl.get_monitors({ all = true })) do
    table.insert(outputs, monitor.name)
  end
  table.sort(outputs)
  local signature = table.concat(outputs, "\n")
  -- Mirroring itself emits monitor events; only react to connector changes.
  if signature == previous_outputs then return end
  previous_outputs = signature

  local external = {}
  for _, name in ipairs(outputs) do
    if name ~= primary then table.insert(external, name) end
  end
  local keep_source = false
  for _, name in ipairs(external) do
    if name == source then keep_source = true end
  end
  if not keep_source then source = external[1] or primary end

  -- Let the source leave mirror mode before reversing direction, avoiding a cycle.
  hl.monitor({ output = source, mode = "preferred", position = "auto",
    scale = source == primary and "auto" or 1, mirror = "" })
  local selected_source = source
  hl.timer(function()
    if previous_outputs ~= signature then return end
    for _, name in ipairs(outputs) do
      if name ~= selected_source then
        hl.monitor({ output = name, mode = "preferred", position = "auto",
          scale = name == primary and "auto" or 1, mirror = selected_source })
      end
    end
  end, { timeout = 150, type = "oneshot" })
end

local function schedule_monitors()
  if pending then return end
  pending = true
  -- Query after the connector event has finished updating compositor state.
  hl.timer(function()
    pending = false
    apply_monitors()
  end, { timeout = 150, type = "oneshot" })
end

hl.monitor({ output = primary, mode = "preferred", position = "auto", scale = "auto" })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
hl.on("monitor.added", schedule_monitors)
hl.on("monitor.removed", schedule_monitors)
hl.on("hyprland.start", schedule_monitors)
schedule_monitors()
