# External monitors use DDC/CI rather than the laptop backlight interface.
{ pkgs, ... }:

let
  brightness = pkgs.writeShellApplication {
    name = "blix-monitor-brightness";
    runtimeInputs = [ pkgs.ddcutil pkgs.gawk pkgs.util-linux pkgs.coreutils ];
    text = ''
      # Serialize bar polling and slider writes on the same monitor.
      exec 9>"''${XDG_RUNTIME_DIR:?}/blix-monitor-brightness.lock"
      flock -w 2 9 || exit 0
      values=$(timeout 8s ddcutil --display 1 --terse getvcp 10) || {
        echo 'N/A'
        exit 0
      }
      read -r current maximum < <(awk '$1 == "VCP" && $2 == "10" && $3 == "C" {print $4, $5}' <<< "$values")
      [[ $current =~ ^[0-9]+$ && $maximum =~ ^[0-9]+$ ]] || exit 1
      (( maximum > 0 )) || exit 1
      if (( $# == 0 )); then
        printf '%d%%\n' "$((current * 100 / maximum))"
      else
        [[ $# == 1 && $1 =~ ^[0-9]{1,3}$ ]] || exit 2
        percent=$((10#$1))
        (( percent >= 1 && percent <= 100 )) || exit 2
        timeout 8s ddcutil --display 1 setvcp 10 "$(((percent * maximum + 99) / 100))"
      fi
    '';
  };
in
{
  home.packages = [ brightness ];
  _module.args.oxwmExtraBarBlocks = ''
    table.insert(blocks, oxwm.bar.block.shell({
      format = "Bri {}",
      command = "${brightness}/bin/blix-monitor-brightness",
      interval = 5,
      color = colors.status.brightness,
      underline = false,
      click = {
        command = "${brightness}/bin/blix-monitor-brightness {}",
        slider = { label = "Brightness", min = 1, max = 100 },
      },
    }))
    table.insert(blocks, oxwm.bar.block.static({
      text = "│",
      color = colors.status.separator,
      underline = false,
    }))
  '';
}
