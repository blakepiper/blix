local outputs, rules, events, queue = {}, {}, {}, {}
hl = {
  get_monitors = function() return outputs end,
  monitor = function(rule) rules[rule.output] = rule end,
  on = function(event, callback) events[event] = callback end,
  timer = function(callback) table.insert(queue, callback) end,
}
local function flush()
  local callbacks = queue
  queue = {}
  for _, callback in ipairs(callbacks) do callback() end
end
local function connect(names, event)
  outputs = {}
  for _, name in ipairs(names) do table.insert(outputs, { name = name }) end
  events[event]()
  flush()
  flush()
end
outputs = { { name = "eDP-1" }, { name = "DP-7" } }
assert(loadfile(arg[1]))()
flush()
flush()
assert(rules["DP-7"].mirror == "" and rules["eDP-1"].mirror == "DP-7")
connect({ "eDP-1" }, "monitor.added")
assert(rules["eDP-1"].mirror == "" and rules["eDP-1"].scale == "auto")
connect({ "eDP-1", "DP-7" }, "monitor.added")
assert(rules["DP-7"].mirror == "" and rules["DP-7"].mode == "preferred")
assert(rules["eDP-1"].mirror == "DP-7")
connect({ "eDP-1", "DP-7", "DP-2" }, "monitor.added")
assert(rules["DP-2"].mirror == "DP-7")
-- Mirror-generated events must not reapply output rules.
local saved = rules["eDP-1"]
connect({ "eDP-1", "DP-7", "DP-2" }, "monitor.removed")
assert(rules["eDP-1"] == saved)
connect({ "eDP-1", "DP-2" }, "monitor.removed")
assert(rules["DP-2"].mirror == "" and rules["eDP-1"].mirror == "DP-2")
connect({ "eDP-1" }, "monitor.removed")
assert(rules["eDP-1"].mirror == "" and rules["eDP-1"].scale == "auto")
