{ config, options, pkgs, ... }:

# Session pointer cursor, projected from ryoku.lib.pointerCursor — the same
# definition the SDDM greeter uses in modules/desktop.nix.

let
  cursor = config.ryoku.lib.pointerCursor;
  hyprlandSystemd = options.wayland.windowManager.hyprland.systemd;
in
{
  home.pointerCursor = {
    enable = true;
    inherit (cursor) name size;
    package = pkgs.${cursor.package};
    gtk.enable = true;
    # x11.enable would take over the existing unmanaged ~/.Xresources;
    # Hyprland already hands its XCursor theme to Xwayland.
    # hyprcursor.enable stays off: Adwaita ships XCursor only.
  };

  # home.sessionVariables only reach login shells, not Hyprland started by SDDM.
  wayland.windowManager.hyprland.settings.env = [
    "XCURSOR_THEME,${cursor.name}"
    "XCURSOR_SIZE,${toString cursor.size}"
  ];

  # Export to systemd/D-Bus user env so DMS and apps it launches inherit them.
  wayland.windowManager.hyprland.systemd.variables =
    hyprlandSystemd.variables.default ++ [ "XCURSOR_THEME" "XCURSOR_SIZE" ];
}
