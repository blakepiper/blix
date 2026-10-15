# Touchscreen access to settings when the Bluetooth keyboard is unavailable.
{ blixSettings, ... }:

{
  _module.args.oxwmExtraBarBlocks = ''
    table.insert(blocks, oxwm.bar.block.static({
      -- Spaces are part of the clickable block, giving the gear a wider target.
      text = "  󰒓  ",
      color = colors.accent,
      underline = false,
      click = { command = "${blixSettings}/bin/blix-settings" },
    }))
    table.insert(blocks, oxwm.bar.block.static({
      text = "│",
      color = colors.status.separator,
      underline = false,
    }))
  '';
}
