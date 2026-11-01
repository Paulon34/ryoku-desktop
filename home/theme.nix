{ config, pkgs, lib, ... }:

let
  # Pre-Matugen placeholder: muted neutrals, replaced by ryoku-hyprland.conf output.
  hyprlandColorsFallback = pkgs.writeText "ryoku-hyprland-colors-fallback.conf" ''
    general {
        col.active_border = rgba(8a9099cc)
        col.inactive_border = rgba(3a3a3a80)
    }
  '';
in
{
  gtk = {
    enable = true;

    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };

    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
  };

  home.file.".local/share/wallpapers" = {
    source = ../assets/wallpapers;
    recursive = true;
  };

  home.file.".local/bin/change-wallpaper" = {
    source = ../scripts/change-wallpaper.sh;
    executable = true;
  };

  # Matugen wants absolute template paths; @HOME@ is the user's home.
  home.file.".config/matugen/config.toml".text =
    builtins.replaceStrings [ "@HOME@" ] [ config.home.homeDirectory ]
      (builtins.readFile ./matugen/config.toml);

  home.file.".config/matugen/templates/waybar.css".source =
    ./matugen/templates/waybar.css;

  home.file.".config/matugen/templates/rofi.rasi".source =
    ./matugen/templates/rofi.rasi;

  home.file.".config/matugen/templates/ryoku-palette.json".source =
    ./matugen/templates/ryoku-palette.json;

  home.file.".config/matugen/templates/ryoku-palette.css".source =
    ./matugen/templates/ryoku-palette.css;

  home.file.".config/matugen/templates/ryoku-rofi.rasi".source =
    ./matugen/templates/ryoku-rofi.rasi;

  # Quattro: gradient active border (surface_tint → tertiary_fixed_dim),
  # shared with the DMS surface frames.
  home.file.".config/matugen/templates/ryoku-hyprland.conf".source =
    if config.ryoku.lib.shellStyle == "quattro" then
      ./matugen/templates/ryoku-hyprland-quattro.conf
    else
      ./matugen/templates/ryoku-hyprland.conf;

  # Matugen writes palette.* and hyprland-colors.conf here on wallpaper change
  # and session start (via DMS). Ensure the dir exists and seed a neutral
  # hyprland-colors.conf only when missing: Hyprland's `source =` errors on a
  # missing file, and Matugen output must never be overwritten.
  home.activation.ensureRyokuConfigDir =
    lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
      run mkdir -p "$HOME/.config/ryoku"
      if [ ! -e "$HOME/.config/ryoku/hyprland-colors.conf" ]; then
        run install -m 644 ${hyprlandColorsFallback} "$HOME/.config/ryoku/hyprland-colors.conf"
      fi
    '';

  # Keep kdeglobals/dolphinrc as mutable files under ~/.config.
  # xdg.configFile would replace them with store symlinks; instead merge only
  # the ColorScheme keys via kwriteconfig6 on activation.
  home.activation.setKdeColorSchemes =
    let
      kwriteconfig6 = lib.getExe' pkgs.kdePackages.kconfig "kwriteconfig6";
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${kwriteconfig6} \
        --file "$HOME/.config/kdeglobals" \
        --group General \
        --key ColorScheme \
        DankMatugen

      run ${kwriteconfig6} \
        --file "$HOME/.config/dolphinrc" \
        --group UiSettings \
        --key ColorScheme \
        DankMatugen
    '';

  qt = {
    enable = true;

    platformTheme.name = "adwaita";

    style = {
      name = "adwaita-dark";
    };
  };

  home.sessionVariables = {
    GTK_THEME = "Adwaita:dark";
  };
}
