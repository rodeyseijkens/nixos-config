{
  pkgs,
  host,
  lib,
  config,
  ...
}: {
  options = {
    networking.firewall.allowedTCPPortsCustom = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [];
      description = "Additional TCP ports to open in the firewall (host-specific)";
    };
    networking.firewall.allowedUDPPortsCustom = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [];
      description = "Additional UDP ports to open in the firewall (host-specific)";
    };
  };

  config = {
    networking = {
      hostName = "${host}";
      networkmanager.enable = true;
      nameservers = ["1.1.1.1" "1.0.0.1"];
      firewall = {
        enable = true;
        allowedTCPPorts = config.networking.firewall.allowedTCPPortsCustom;
        allowedUDPPorts = config.networking.firewall.allowedUDPPortsCustom;
      };
      enableIPv6 = false;
    };

    environment.systemPackages = with pkgs; [
      networkmanagerapplet
    ];
  };
}
