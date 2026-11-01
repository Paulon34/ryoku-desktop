{ config, ... }:

{
  services.hyprpaper = {
    enable = false;

    settings = {
      ipc = true;
      splash = false;

      wallpaper = [
        {
          monitor = "eDP-1";
          path = "${config.home.homeDirectory}/.local/share/wallpapers";
          fit_mode = "cover";
          order = "random";
        }

        {
          monitor = "HDMI-A-1";
          path = "${config.home.homeDirectory}/.local/share/wallpapers";
          fit_mode = "cover";
          order = "random";
        }
      ];
    };
  };
}
