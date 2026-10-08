# Temporary first-install access. Remove this import after establishing normal
# login credentials and a replacement management connection. No Wi-Fi secrets.
{ config, ... }:

let
  phoneAddress = config.mobile.boot.stage-1.networking.IP;
  hostAddress = config.mobile.boot.stage-1.networking.hostIP;
in
{
  mobile.boot.stage-1.networking.enable = true;
  # Upstream's stage-1 SSH bypasses authentication; stage-2 SSH below uses keys.
  mobile.boot.stage-1.ssh.enable = false;

  # The computer uses a temporary NetworkManager "shared" connection at
  # hostAddress. Keep all stage-2 networking under the ordinary Blix NM service.
  networking.networkmanager.ensureProfiles.profiles.blix-phone-usb-bootstrap = {
    connection = {
      id = "blix-phone-usb-bootstrap";
      type = "ethernet";
      interface-name = "usb0";
      autoconnect = true;
    };
    ipv4 = {
      method = "manual";
      address1 = "${phoneAddress}/24,${hostAddress}";
      # Query upstream DNS over NAT; no extra DNS firewall rules on the computer.
      dns = "1.1.1.1;9.9.9.9;";
      route-metric = 2000;
      dns-priority = 2000;
    };
    ipv6.method = "disabled";
  };

  services.openssh = {
    enable = true;
    openFirewall = false;
    listenAddresses = [ { addr = phoneAddress; port = 22; } ];
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      AllowUsers = [ "root" "przvl" ];
    };
  };
  networking.firewall.interfaces.usb0 = {
    allowedTCPPorts = [ 22 ];
  };
  systemd.services.sshd = {
    after = [ "NetworkManager-ensure-profiles.service" "network-online.target" ];
    wants = [ "network-online.target" ];
  };

  users.users.root.openssh.authorizedKeys.keyFiles = [ ./bootstrap.pub ];
  users.users.przvl.openssh.authorizedKeys.keyFiles = [ ./bootstrap.pub ];
}
