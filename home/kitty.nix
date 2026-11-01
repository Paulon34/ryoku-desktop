{ pkgs, ... }:

{
  programs.kitty = {
    enable = true;

    font = {
      name = "JetBrainsMono Nerd Font";
      size = 11;
    };

    settings = {
      confirm_os_window_close = 0;

      # Colors come from the DMS-generated theme included below. Keep the
      # compositor responsible for blur and Kitty responsible for opacity.
      background_opacity = "0.90";

      window_padding_width = 12;

      enable_audio_bell = false;
      visual_bell_duration = "0.08";
      window_alert_on_bell = false;

      scrollback_lines = 10000;

      cursor_shape = "beam";
      cursor_blink_interval = 0;

      shell = "fish";
    };

    # DMS rewrites this file whenever the wallpaper palette changes. Kitty's
    # config watcher reloads includes automatically, so no extra daemon is
    # needed here.
    extraConfig = ''
      # Reset for every child shell, including new tabs/windows and Kitty
      # instances launched from an existing Fish. Nested Fish inherits the
      # non-empty marker set by the top-level shell instead.
      env RYOKU_FISH_SESSION=

      include dank-theme.conf
    '';

    keybindings = {
      "ctrl+shift+enter" = "new_window";
      "ctrl+shift+t" = "new_tab";
      "ctrl+shift+w" = "close_tab";
      "ctrl+shift+left" = "previous_tab";
      "ctrl+shift+right" = "next_tab";

      "ctrl+shift+c" = "copy_to_clipboard";
      "ctrl+shift+v" = "paste_from_clipboard";
    };
  };

  home.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];
}
