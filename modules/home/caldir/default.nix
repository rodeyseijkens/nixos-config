{ ... }: {
  # Calendar data lives in a dot directory in the home root. The sync writes
  # .ics files there, so only the configuration is managed here.
  xdg.configFile."caldir/config.toml".source = ./config.toml;
}
