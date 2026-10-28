# RTX 3070 reporting belongs to this host, not the shared desktop profile.
{ pkgs, osConfig, ... }:

let
  gpu = pkgs.writeShellApplication {
    name = "oxwm-gpu";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      if usage=$(timeout 3 ${osConfig.hardware.nvidia.package.bin}/bin/nvidia-smi \
        --id=0 --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null) \
        && [[ "$usage" =~ ^[0-9]+$ ]] && (( usage <= 100 )); then
        printf '%s%%\n' "$usage"
      else
        printf 'N/A\n'
      fi
    '';
  };
in
{
  blix.neofetch.showGpu = true;

  _module.args.oxwmExtraBarBlocks = ''
    table.insert(blocks, oxwm.bar.block.shell({
      format = "GPU: {}",
      command = "${gpu}/bin/oxwm-gpu",
      interval = 5,
      color = colors.status.cpu,
      underline = false,
    }))
    table.insert(blocks, oxwm.bar.block.static({
      text = "│",
      color = colors.status.separator,
      underline = false,
    }))
  '';
}
