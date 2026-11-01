{ osConfig, pkgs, ... }:

{
  programs.fish = {
    enable = true;

    shellAliases = {
      ll = "ls -lah";
      la = "ls -A";
      l = "ls -CF";

      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git log --oneline --graph --decorate";

      rebuild = "sudo nixos-rebuild switch --flake ${osConfig.ryoku.settingsApply.repoPath}#${osConfig.ryoku.settingsApply.flakeHost}";
      update-nix = "nix flake update --flake ${osConfig.ryoku.settingsApply.repoPath}";
    };

    interactiveShellInit = ''
      set fish_greeting ""

      function __ryoku_terminal_intro
        # Four finite frames (120 ms total), colored by Kitty's dynamic ANSI
        # palette. The final mascot is rendered by the compact Fastfetch logo.
        printf '\r\e[2K\e[2;34m      ·\e[0m'
        command sleep 0.03
        printf '\r\e[2K\e[34m     ◌\e[0m'
        command sleep 0.03
        printf '\r\e[2K\e[36m    ᜊ\e[0m'
        command sleep 0.03
        printf '\r\e[2K\e[1;36m  ᜊ  Ryoku\e[0m'
        command sleep 0.03
        printf '\r\e[2K'

        if type -q fastfetch
          fastfetch
        end
      end

      # Kitty resets this marker for every new window/tab. The first Fish sets
      # and exports it; nested Fish processes inherit it and skip the intro.
      set -l __ryoku_is_top_level false
      if not set -q RYOKU_FISH_SESSION; or test -z "$RYOKU_FISH_SESSION"
        set -gx RYOKU_FISH_SESSION "$fish_pid"
        set __ryoku_is_top_level true
      end

      # RYOKU_SKIP_INTRO=1 keeps automation out of debugging or
      # latency-sensitive terminal launches.
      if test "$__ryoku_is_top_level" = true; and set -q KITTY_WINDOW_ID; and not set -q SSH_CONNECTION; and not set -q SSH_TTY; and not set -q RYOKU_SKIP_INTRO; and test "$TERM" != dumb
        __ryoku_terminal_intro
      end

      functions --erase __ryoku_terminal_intro
      set --erase __ryoku_is_top_level
    '';
  };

  home.packages = with pkgs; [
    fish
    starship
  ];

  programs.starship = {
    enable = true;
    enableFishIntegration = true;

    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$status$character";

      directory = {
        format = "[$path]($style) ";
        style = "bold blue";
        truncation_length = 3;
        truncate_to_repo = false;
      };

      git_branch = {
        format = "[git:$branch]($style) ";
        style = "cyan";
        symbol = "";
      };

      git_status = {
        format = "[$all_status$ahead_behind]($style) ";
        style = "yellow";
      };

      cmd_duration = {
        min_time = 2000;
        format = "[$duration]($style) ";
        style = "dimmed white";
      };

      status = {
        disabled = false;
        format = "[$status]($style) ";
        style = "bold red";
      };

      character = {
        success_symbol = "[❯](bold cyan)";
        error_symbol = "[❯](bold red)";
      };
    };
  };

  # Fastfetch is installed system-wide by modules/base.nix. Named ANSI colors
  # follow Kitty's DMS palette without parsing palette.json on every launch.
  xdg.configFile."fastfetch/config.jsonc".text = builtins.toJSON {
    logo = {
      type = "data";
      source = ''
           .-.   Ryoku
          (o o)  Terminal
          | O \
           \   \
            `~~~'
      '';
      color = {
        "1" = "cyan";
        "2" = "blue";
      };
      padding.right = 2;
    };

    display = {
      separator = "  ";
      size.binaryPrefix = "iec";
      percent.type = 2;
      bar.width = 10;
    };

    modules = [
      { type = "os"; key = "OS"; keyColor = "blue"; }
      { type = "kernel"; key = "Kernel"; keyColor = "blue"; }
      { type = "uptime"; key = "Uptime"; keyColor = "blue"; }
      { type = "packages"; key = "Packages"; keyColor = "blue"; }
      { type = "shell"; key = "Shell"; keyColor = "blue"; }
      { type = "wm"; key = "Compositor"; keyColor = "blue"; }
      { type = "terminal"; key = "Terminal"; keyColor = "blue"; }
      { type = "cpu"; key = "CPU"; keyColor = "blue"; }
      { type = "gpu"; key = "GPU"; keyColor = "blue"; hideType = "integrated"; }
      { type = "memory"; key = "RAM"; keyColor = "blue"; }
      { type = "disk"; key = "Disk"; keyColor = "blue"; folders = "/"; }
    ];
  };
}
