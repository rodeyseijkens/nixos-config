{
  pkgs,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.modules.devpod;
in {
  options.modules.devpod = {enable = mkEnableOption "devpod";};
  config = mkIf cfg.enable {
    services.ssh-agent.enable = true;

    systemd.user.services.devpod-ssh-symlink = {
      Unit = {
        Description = "Create SSH agent symlink for DevPod";
        After = ["ssh-agent.service"];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c 'mkdir -p %t/keyring && ln -sf %t/ssh-agent %t/keyring/ssh'";
        RemainAfterExit = true;
      };
      Install.WantedBy = ["default.target"];
    };

    home.packages = with pkgs; [
      devpod-desktop
      awscli2
      docker
    ];
  };
}
