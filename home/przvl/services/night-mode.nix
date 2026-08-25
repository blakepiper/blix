{ nightMode, ... }:

{
  # Night mode is a long-lived gammastep process rather than a one-shot
  # command, because the compositor resets the gamma ramps when the client
  # setting them exits. Giving it its own unit keeps it out of the bar's
  # cgroup, where restarting the bar would take the warm screen down with it.
  # `night-mode run` reads the wanted mode, so starting this unit with the
  # session also restores the mode across a compositor restart.
  systemd.user.services.night-mode = {
    Unit = {
      Description = "Warm the display while night mode is on";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${nightMode}/bin/night-mode run";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
