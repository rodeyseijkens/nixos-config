{
  pkgs,
  lib,
  ...
}:
with lib; let
  defaultApps = {
    browser = ["firefox.desktop"];
    text = ["org.gnome.TextEditor.desktop"];
    image = ["viewnior.desktop"];
    audio = ["mpv.desktop"];
    video = ["mpv.desktop"];
    directory = ["nemo.desktop" "org.gnome.Nautilus.desktop"];
    pdf = ["org.gnome.Evince.desktop"];
    terminal = ["kitty.desktop"];
    archive = ["org.gnome.FileRoller.desktop"];
    discord = ["webcord.desktop"];
  };

  mimeMap = {
    text = ["text/plain"];
    image = [
      "image/bmp"
      "image/gif"
      "image/jpeg"
      "image/jpg"
      "image/png"
      "image/svg+xml"
      "image/tiff"
      "image/vnd.microsoft.icon"
      "image/webp"
    ];
    audio = [
      "audio/aac"
      "audio/mpeg"
      "audio/ogg"
      "audio/opus"
      "audio/wav"
      "audio/webm"
      "audio/x-matroska"
    ];
    video = [
      "video/mp2t"
      "video/mp4"
      "video/mpeg"
      "video/ogg"
      "video/webm"
      "video/x-flv"
      "video/x-matroska"
      "video/x-msvideo"
    ];
    directory = ["inode/directory"];
    browser = [
      "text/html"
      "x-scheme-handler/about"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
      "x-scheme-handler/unknown"
    ];
    pdf = ["application/pdf"];
    terminal = ["terminal"];
    archive = [
      "application/zip"
      "application/rar"
      "application/7z"
      "application/*tar"
    ];
    discord = ["x-scheme-handler/discord"];
  };

  associations = with lists;
    listToAttrs (
      flatten (mapAttrsToList (key: map (type: attrsets.nameValuePair type defaultApps."${key}")) mimeMap)
    );
in {
  xdg.configFile."mimeapps.list".force = true;
  xdg.mimeApps.enable = true;
  xdg.mimeApps.associations.added = associations;
  xdg.mimeApps.defaultApplications = associations;

  home.packages = with pkgs; [junction];

  home.sessionVariables = {
    # prevent wine from creating file associations
    WINEDLLOVERRIDES = "winemenubuilder.exe=d";
  };
}
