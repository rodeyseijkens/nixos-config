{stylixColors}:
with stylixColors; {
  "error" = base08;
  "warning" = base0A;
  "info" = base0B;
  "hint" = base03;
  "diagnostic.error" = {
    underline = {
      color = base08;
      style = "curl";
    };
  };
  "diagnostic.warning" = {
    underline = {
      color = base0A;
      style = "curl";
    };
  };
  "diagnostic.info" = {
    underline = {
      color = base0B;
      style = "curl";
    };
  };
  "diagnostic.hint" = {
    underline = {
      color = base03;
      style = "curl";
    };
  };

  "diff.plus" = base0D;
  "diff.minus" = base08;
  "diff.delta" = base0B;

  "ui.background" = {bg = base00;};
  "ui.text" = base06;
  "ui.text.focus" = base06;
  "ui.cursor" = {
    fg = base00;
    bg = base06;
  }; # editorCursor.foreground
  "ui.cursor.primary" = {
    fg = base00;
    bg = base06;
  };
  "ui.cursor.match" = {bg = "#58524b";};
  "ui.cursorline" = {bg = "#292929";};
  "ui.selection" = {bg = "#303f33";};
  "ui.linenr" = {fg = base03;};
  "ui.linenr.selected" = {fg = base04;};
  "ui.statusline" = {
    fg = base06;
    bg = base01;
  };
  "ui.statusline.inactive" = {
    fg = base04;
    bg = base01;
  };
  "ui.statusline.normal" = {
    fg = base00;
    bg = base04;
  };
  "ui.statusline.insert" = {
    fg = base00;
    bg = base0D;
  };
  "ui.statusline.select" = {
    fg = base00;
    bg = base09;
  };
  "ui.popup" = {
    fg = base06;
    bg = base01;
  };
  "ui.menu" = {
    fg = base06;
    bg = base01;
  };
  "ui.menu.selected" = {bg = base02;};
  "ui.help" = {
    fg = base06;
    bg = base01;
  };
  "ui.window" = {fg = base01;};
  "ui.gutter" = {bg = base00;};
  "ui.highlight" = {bg = "#354738";};
  "ui.virtual.whitespace" = {fg = "#2e2f2d";};
  "ui.virtual.indent-guide" = {fg = base02;};
  "ui.virtual.inlay-hint" = {fg = "#6c6459";};
}
