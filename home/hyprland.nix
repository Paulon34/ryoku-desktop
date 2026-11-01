{ config, osConfig, pkgs, lib, ... }:

let
  # Quattro (default) takes Omarchy Quattro's window look: small shared
  # radius, no dimming of inactive windows, flat (no shadow outside the
  # Cinematic profile), and its animation set. Islands keeps the earlier look.
  quattro = config.ryoku.lib.shellStyle == "quattro";
in
{
  wayland.windowManager.hyprland = {

    configType = "hyprlang";
    enable = true;
    settings = {
      "$mod" = "SUPER";
      "$terminal" = "kitty";
      "$menu" = "dms ipc call launcher toggle";
      "$fileManager" = "dolphin";

      # Border colors from the Matugen palette (home/matugen/templates/ryoku-hyprland.conf).
      # Emitted first (sourceFirst), so col.* must not be set in these settings.
      source = [ "~/.config/ryoku/hyprland-colors.conf" ];

      # Host-specific (ryoku.desktop.monitors); Ryoku Settings › Displays edits them at runtime.
      monitor = osConfig.ryoku.desktop.monitors;

      exec-once = [
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
      ];

      input = {
        kb_layout = osConfig.ryoku.desktop.keyboardLayout;
        # NumLock state applied once when each keyboard is set up (session start).
        numlock_by_default = true;
        follow_mouse = 1;

        touchpad = {
          natural_scroll = true;
          tap-to-click = true;
        };

        sensitivity = 0;
      };

      general = {
        gaps_in = 5;
        gaps_out = 10;

        border_size = 2;

        layout = "dwindle";

        resize_on_border = true;
      };

      decoration = {
        # Shared with the DMS cornerRadius (home/dms.nix), as Omarchy's shell
        # mirrors decoration:rounding.
        rounding = if quattro then 8 else 12;

        active_opacity = 1.0;
        # Quattro: no dimming. A translucent inactive window also forces a
        # blur pass behind it on every video wallpaper frame.
        inactive_opacity = if quattro then 1.0 else 0.96;

        # Balanced visual profile. DMS (RyokuVisual) adjusts blur/shadow at
        # runtime per profile and caps it over a video wallpaper; keep these
        # values in sync with its Balanced/static-wallpaper entry.
        blur = {
          enabled = true;
          size = 6;
          passes = 2;
          new_optimizations = true;
        };

        shadow = {
          enabled = !quattro;
          range = 14;
          render_power = 3;
          offset = "0 3";
          color = "rgba(00000059)";
          color_inactive = "rgba(0000002e)";
        };
      };

      animations = {
        enabled = true;

        bezier = [
          "easeOutQuint,0.23,1,0.32,1"
          "easeInOutCubic,0.65,0.05,0.36,1"
        ] ++ lib.optionals quattro [
          "linear,0,0,1,1"
          "almostLinear,0.5,0.5,0.75,1"
          "quick,0.15,0,0.1,1"
        ];

        # Quattro: Omarchy Quattro's timings (default/hypr/looknfeel.lua) —
        # windows pop in from 87 %, leave faster than they came, layers fade
        # briefly, workspace switches are instant.
        animation =
          if quattro then
            [
              "global,1,8,default"
              "border,1,4.31,easeOutQuint"
              "windows,1,3.03,easeOutQuint"
              "windowsIn,1,3.28,easeOutQuint,popin 87%"
              "windowsOut,1,1.19,linear,popin 87%"
              "fadeIn,1,1.38,almostLinear"
              "fadeOut,1,1.17,almostLinear"
              "fade,1,2.42,quick"
              "fadeSwitch,0"
              "layers,1,3.05,easeOutQuint"
              "layersIn,1,3.2,easeOutQuint,fade"
              "layersOut,1,1.2,linear,fade"
              "fadeLayersIn,1,1.43,almostLinear"
              "fadeLayersOut,1,1.11,almostLinear"
              "workspaces,0"
            ]
          else
            [
              "windows,1,5,easeOutQuint"
              "windowsOut,1,4,easeInOutCubic,popin 80%"
              "border,1,6,easeOutQuint"
              "fade,1,5,easeOutQuint"
              "workspaces,1,5,easeOutQuint"
            ];
      };

      # DMS animates its own surfaces in QML (grow from the icon, instant
      # launcher/OSD); a compositor fade on top only washes them out.
      layerrule = lib.optionals quattro [
        "no_anim on, match:namespace ^(dms:.*)$"
      ];

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
      };

      # Utility windows float centered instead of breaking the tiling layout.
      # Classes verified on this system; sizes only for main windows so their
      # sub-dialogs keep their natural size. Hyprland ≥ 0.53 rule syntax.
      windowrule = [
        "float on, center on, size 900 620, match:class ^(xdg-desktop-portal-gtk)$"
        "float on, center on, size 920 640, match:class ^(org\\.pulseaudio\\.pavucontrol)$"
        "float on, center on, match:class ^(blueman-manager)$"
        "size 760 540, match:class ^(blueman-manager)$, match:title ^(Bluetooth Devices|Dispositivos Bluetooth)$"
        "float on, center on, match:class ^(nm-connection-editor)$"
        "size 760 560, match:class ^(nm-connection-editor)$, match:title ^(Network Connections|Conexões de rede)$"
        # In-app Qt/GTK file dialogs (exact titles, EN + PT-BR).
        "float on, center on, match:title ^(Open File|Save File|Open Folder|Select Folder|Save As|Abrir arquivo|Salvar arquivo|Abrir pasta|Selecionar pasta|Salvar como)$"
      ];

      bind = [
        # Apps
        "$mod, RETURN, exec, $terminal"
        "$mod, SPACE, exec, $menu"
        "$mod, E, exec, $fileManager"

        # Janela
        "$mod, Q, killactive"
        "$mod, F, fullscreen"
        "$mod, V, togglefloating"
        "$mod, P, pseudo"

        # Sair
        "$mod SHIFT, E, exit"

        # Navegação
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"

        "$mod, H, movefocus, l"
        "$mod, K, movefocus, u"
        "$mod, J, movefocus, d"

        # Mover janelas
        "$mod SHIFT, H, movewindow, l"
        "$mod SHIFT, L, movewindow, r"
        "$mod SHIFT, K, movewindow, u"
        "$mod SHIFT, J, movewindow, d"

        # Workspaces
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"

        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"

	"$mod, mouse_down, workspace, e+1"
	"$mod, mouse_up, workspace, e-1"

       "$mod, W, exec, bash ${config.home.homeDirectory}/.local/bin/change-wallpaper"

 # Screenshot
        ", Print, exec, grim -g \"$(slurp)\" - | swappy -f -"
        "$mod, Print, exec, grim ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"

        # Clipboard
        "$mod, C, exec, cliphist list | rofi -dmenu | cliphist decode | wl-copy"

        # Lock
        "$mod, X, exec, hyprlock"
        "$mod, L, exec, dms ipc call lock lock"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      bindel = [
        ",XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"

        ",XF86MonBrightnessUp, exec, brightnessctl set +5%"
        ",XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];
    };
  };

  home.packages = with pkgs; [
    rofi
    mako
    hyprpaper
    hyprlock
    hypridle
    wl-clipboard
    cliphist
    grim
    slurp
    swappy
    brightnessctl
  ];
}
