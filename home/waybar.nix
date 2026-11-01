{ pkgs, ... }:

{
  programs.waybar = {
    enable = true;

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 32;

        spacing = 8;

        modules-left = [
          "hyprland/workspaces"
          "hyprland/window"
        ];

        modules-center = [
          "clock"
        ];

        modules-right = [
          "cpu"
          "memory"
          "network"
          "pulseaudio"
          "battery"
          "tray"
        ];

        "hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
          format = "{name}";
        };

        "hyprland/window" = {
          format = "{}";
          max-length = 50;
        };

        clock = {
          format = "{:%H:%M}";
          format-alt = "{:%d/%m/%Y %H:%M}";
          tooltip-format = "<big>{:%A, %d %B %Y}</big>";
        };

        cpu = {
          interval = 2;
          format = " {usage}%";
          tooltip = true;
        };

        memory = {
          interval = 2;
          format = " {}%";
        };

        network = {
          interval = 3;

          format-wifi = " {signalStrength}%";
          format-ethernet = "󰈀 {ipaddr}";
          format-disconnected = "󰤭 Offline";

          tooltip-format-wifi = "{essid}\n{ipaddr}";
          tooltip-format-ethernet = "{ifname}\n{ipaddr}";
        };

        pulseaudio = {
          format = "{icon} {volume}%";
          format-muted = "󰝟 muted";

          format-icons = {
            default = [
              ""
              ""
              ""
            ];
          };

          on-click = "pavucontrol";
        };

        battery = {
          states = {
            warning = 30;
            critical = 15;
          };

          format = "{icon} {capacity}%";
          format-charging = "󰂄 {capacity}%";
          format-plugged = " {capacity}%";

          format-icons = [
            "󰁺"
            "󰁻"
            "󰁼"
            "󰁽"
            "󰁾"
            "󰁿"
            "󰂀"
            "󰂁"
            "󰂂"
            "󰁹"
          ];
        };

        tray = {
          spacing = 10;
        };
      };
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
        border: none;
        border-radius: 0;
      }

      window#waybar {
        background: rgba(20, 20, 28, 0.90);
        color: #e6e6e6;
      }

      #workspaces {
        margin-left: 8px;
      }

      #workspaces button {
        padding: 0 8px;
        margin: 4px 2px;
        border-radius: 8px;
        color: #a6adc8;
        background: transparent;
      }

      #workspaces button.active {
        color: #ffffff;
        background: rgba(255, 255, 255, 0.15);
      }

      #workspaces button.urgent {
        background: rgba(255, 80, 80, 0.35);
      }

      #window {
        margin-left: 8px;
      }

      #clock,
      #cpu,
      #memory,
      #network,
      #pulseaudio,
      #battery,
      #tray {
        padding: 0 10px;
        margin: 4px 2px;
        border-radius: 8px;
        background: rgba(255, 255, 255, 0.06);
      }

      #battery.warning {
        background: rgba(255, 190, 60, 0.20);
      }

      #battery.critical {
        background: rgba(255, 70, 70, 0.25);
      }

      tooltip {
        background: #181825;
        border-radius: 8px;
      }

      tooltip label {
        color: #e6e6e6;
      }
    '';
  };

  home.packages = with pkgs; [
    pavucontrol
  ];
}