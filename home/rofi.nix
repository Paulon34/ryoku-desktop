{ pkgs, config, lib, ... }:

let
  ryokuRofi = "${config.home.homeDirectory}/.config/ryoku/rofi.rasi";
  jq = lib.getExe pkgs.jq;
in
{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
  };

  # Bootstrap RASI adapter from canonical palette.json so Rofi works after
  # rebuild before the next wallpaper/Matugen run. Matugen overwrites this
  # file on wallpaper change with the same tokens.
  home.activation.bootstrapRyokuRofiAdapter =
    lib.hm.dag.entryAfter [ "ensureRyokuConfigDir" ] ''
      palette="$HOME/.config/ryoku/palette.json"
      adapter="$HOME/.config/ryoku/rofi.rasi"

      run mkdir -p "$HOME/.config/ryoku"

      if [ -f "$palette" ]; then
        ${jq} -r '
          "* {\n" +
          "    ryoku-primary: \(.primary);\n" +
          "    ryoku-on-primary: \(.on_primary);\n" +
          "    ryoku-surface: \(.surface);\n" +
          "    ryoku-surface-container: \(.surface_container);\n" +
          "    ryoku-surface-container-high: \(.surface_container_high);\n" +
          "    ryoku-on-surface: \(.on_surface);\n" +
          "    ryoku-outline: \(.outline);\n" +
          "    ryoku-error: \(.error);\n" +
          "}\n"
        ' "$palette" > "$adapter.tmp"
        run ${pkgs.coreutils}/bin/mv "$adapter.tmp" "$adapter"
      elif [ ! -f "$adapter" ]; then
        printf '%s\n' \
          '* {' \
          '    ryoku-primary: #e2e9ff;' \
          '    ryoku-on-primary: #000000;' \
          '    ryoku-surface: #111318;' \
          '    ryoku-surface-container: #111318;' \
          '    ryoku-surface-container-high: #2c2d33;' \
          '    ryoku-on-surface: #ffffff;' \
          '    ryoku-outline: #dbdce6;' \
          '    ryoku-error: #ffe3e0;' \
          '}' > "$adapter.tmp"
        run ${pkgs.coreutils}/bin/mv "$adapter.tmp" "$adapter"
      fi
    '';

  xdg.configFile."rofi/config.rasi".text = ''
    configuration {
      modi: "drun,run";
      show-icons: true;
      display-drun: "";
      drun-display-format: "{name}";
      font: "JetBrainsMono Nerd Font 13";
      icon-theme: "Adwaita";
    }

    @theme "theme"
  '';

  xdg.configFile."rofi/theme.rasi".text = ''
    @import "${ryokuRofi}"

    * {
      background-color: transparent;
      text-color: @ryoku-on-surface;
    }

    window {
      location: center;
      anchor: center;
      width: 620px;
      border: 1px;
      border-color: @ryoku-outline;
      border-radius: 20px;
      background-color: @ryoku-surface;
      padding: 22px;
    }

    mainbox {
      spacing: 16px;
      children: [ inputbar, listview ];
    }

    inputbar {
      spacing: 12px;
      padding: 14px 16px;
      border-radius: 14px;
      background-color: @ryoku-surface-container-high;
      children: [ prompt, entry ];
    }

    prompt {
      text-color: @ryoku-primary;
      font: "JetBrainsMono Nerd Font 14";
    }

    entry {
      placeholder: "Pesquisar aplicativo...";
      placeholder-color: @ryoku-outline;
      text-color: @ryoku-on-surface;
      cursor: text;
      vertical-align: 0.5;
    }

    listview {
      columns: 1;
      lines: 8;
      spacing: 6px;
      scrollbar: false;
      fixed-height: true;
      dynamic: true;
    }

    element {
      spacing: 14px;
      padding: 12px 14px;
      border-radius: 14px;
      background-color: transparent;
      text-color: @ryoku-on-surface;
      children: [ element-icon, element-text ];
    }

    element normal.normal {
      background-color: transparent;
      text-color: @ryoku-on-surface;
    }

    element alternate.normal {
      background-color: transparent;
      text-color: @ryoku-on-surface;
    }

    element selected.normal {
      background-color: @ryoku-primary;
      text-color: @ryoku-on-primary;
    }

    element-icon {
      size: 32px;
      cursor: inherit;
    }

    element selected.normal element-icon {
      text-color: @ryoku-on-primary;
    }

    element-text {
      vertical-align: 0.5;
      cursor: inherit;
      text-color: inherit;
    }
  '';
}
