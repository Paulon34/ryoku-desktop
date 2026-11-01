{
  lib,
  ...
}:

# Home Manager reader for ryoku/settings.json (Phase 7A).
#
# Infrastructure only: expose parsed settings + helpers. Do not migrate
# gtk/qt/hyprland/kitty/rofi yet — null keys must leave home/*.nix in charge.
#
# Ownership: once a key is migrated to Ryoku Settings, ryoku/settings.json is
# canonical for that key. ~/.config/DankMaterialShell/settings.json stays for
# unmigrated DMS shell prefs / runtime state.

let
  ryokuLib = import ../ryoku/lib.nix { inherit lib; };
in
{
  options.ryoku = {
    settings = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = ryokuLib.settings;
      description = ''
        Parsed ryoku/settings.json. Future Appearance/desktop projections
        will use ryoku.lib.orExisting so null never changes current HM config.
      '';
    };

    lib = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = {
        inherit (ryokuLib)
          isSet
          orExisting
          get
          appearance
          desktop
          hyprland
          dynamicColors
          wallpaper
          wallpaperType
          videoWallpaper
          visualProfile
          visualProfileAuto
          iconTheme
          cursorTheme
          pointerCursor
          fontUi
          fontMono
          transparency
          animations
          gapsIn
          gapsOut
          rounding
          weatherLocation
          shellStyle
          ;
      };
      description = "Helpers for projecting Ryoku settings into HM modules.";
      visible = false;
    };
  };

  # No home.* projections here — consumers read ryoku.lib (e.g. home/dms.nix
  # projects weatherLocation into DMS).
  config = { };
}
