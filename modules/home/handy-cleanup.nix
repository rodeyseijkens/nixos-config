{
  pkgs,
  lib,
  config,
  ...
}: {
  # Handy (com.pais.handy) wrote its own XDG autostart entry when it first ran,
  # so removing the package left it relaunching from the tray on hosts that had
  # used it. Drop the leftover entry and stop any instance still running.
  # Remove this module once every host has switched since Handy was dropped.
  home.activation.removeHandyAutostart = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run ${pkgs.coreutils}/bin/rm -f "${config.xdg.configHome}/autostart/Handy.desktop"
    run ${pkgs.procps}/bin/pkill -x handy || true
  '';
}
