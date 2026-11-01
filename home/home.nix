{ osConfig, lib, ... }:

{
  imports = [
    ./fish.nix
    ./kitty.nix
    ./hyprland.nix
    ./waybar.nix
    ./git.nix
   ./rofi.nix
./theme.nix
./hyprpaper.nix
./video-wallpaper.nix
./dms.nix
./ryoku.nix
./cursor.nix
  ]
  # Android mirroring (Scrcpy GUI AppImage) — ryoku.features.phoneTools.
  ++ lib.optional osConfig.ryoku.features.phoneTools ./scrcpy-gui.nix;

  home.username = osConfig.ryoku.user.name;
  home.homeDirectory = "/home/${osConfig.ryoku.user.name}";

  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
}
