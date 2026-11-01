{ config, lib, ... }:

# Ryoku core options. A host (hosts/<name>/default.nix, written by hand or by
# scripts/ryoku-bootstrap) sets these; every Ryoku module reads them instead of
# hard-coding a user, a machine or personal applications.

let
  inherit (lib) mkOption mkEnableOption types;
  cfg = config.ryoku;
  full = cfg.profile == "full";

  feature = description: default:
    mkOption {
      type = types.bool;
      inherit default;
      description = description + " (default follows ryoku.profile).";
    };
in
{
  options.ryoku = {
    user = {
      name = mkOption {
        type = types.strMatching "[a-z_][a-z0-9_-]*";
        example = "alice";
        description = "Login of the Ryoku desktop user (created by Ryoku, Home Manager runs for it).";
      };

      description = mkOption {
        type = types.str;
        default = "";
        description = "GECOS full name of the user.";
      };

      extraGroups = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Groups added on top of the ones Ryoku derives from enabled features.";
      };

      homeModules = mkOption {
        type = types.listOf types.deferredModule;
        default = [ ];
        description = "Extra Home Manager modules for the user (personal git identity, apps, …).";
      };
    };

    host.bootReviewed = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Hosts written by scripts/ryoku-bootstrap set this to false in boot.nix:
        the boot loader there is a suggestion read from the running system, and
        evaluation fails until a person has checked it and set this to true.
      '';
    };

    profile = mkOption {
      type = types.enum [ "minimal" "full" ];
      default = "minimal";
      description = ''
        minimal: the Ryoku desktop (Hyprland, DMS shell with Quattro/Islands,
        Ryoku Settings, Material You, video wallpaper) plus essential tools.
        full: minimal plus the optional feature sets below and extra apps.
        Each feature can still be switched on or off individually.
      '';
    };

    features = {
      apps = feature "Extra desktop applications (office, chat, media players, utilities)" full;
      development = feature "Developer toolchains, editors and direnv" full;
      networkTools = feature "Network diagnostics (nmap, Wireshark, tcpdump, …)" full;
      cybersecurity = feature "Security testing tools (Metasploit, Burp, hashcat, …)" false;
      virtualization = feature "libvirt/QEMU, Docker and Podman" full;
      gaming = feature "Steam, gamemode, gamescope, Lutris, Heroic, Wine" full;
      multimedia = feature "OBS, GIMP, Audacity, LibreOffice, VLC" full;
      printing = feature "CUPS with HP/Gutenprint drivers and network printer discovery" full;
      flatpak = feature "Flatpak with the declarative list from ryoku/settings.json" true;
      phoneTools = feature "Android mirroring (scrcpy, Scrcpy GUI) and a v4l2loopback phone webcam" false;
      tailscale = feature "Tailscale mesh VPN" false;
      ssh = feature "OpenSSH server (key-only unless ssh.passwordAuthentication)" false;
    };

    ssh.passwordAuthentication = mkOption {
      type = types.bool;
      default = false;
      description = "Allow SSH password logins when ryoku.features.ssh is on.";
    };

    hardware = {
      intelVideoAcceleration = mkEnableOption "VA-API on Intel iGPUs (intel-media-driver), used by the video wallpaper";

      nvidia = {
        enable = mkEnableOption ''
          the proprietary NVIDIA driver. Never turned on by detection: the
          bootstrap only writes a commented template'';

        open = mkOption {
          type = types.bool;
          default = true;
          description = "Use the open kernel modules (Turing and newer).";
        };

        prime = {
          enable = mkEnableOption "PRIME render offload (hybrid Intel/AMD + NVIDIA laptops)";
          intelBusId = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "PCI:0@0:2:0";
          };
          amdgpuBusId = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "PCI:5@0:0:0";
          };
          nvidiaBusId = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "PCI:1@0:0:0";
          };
        };
      };
    };

    desktop = {
      monitors = mkOption {
        type = types.listOf types.str;
        default = [ ",preferred,auto,1" ];
        description = "Hyprland monitor lines (name,mode,position,scale). Ryoku Settings › Displays can change them at runtime.";
      };

      keyboardLayout = mkOption {
        type = types.str;
        default = "us";
        example = "br";
        description = "XKB layout for Hyprland.";
      };
    };
  };

  # full pulls unfree apps (Steam, VS Code, Spotify, …); minimal needs none.
  # Defined only for full, so minimal also works with a read-only pkgs (NixOS tests).
  config.nixpkgs.config = lib.mkIf full { allowUnfree = lib.mkDefault true; };

  config.assertions = [
    {
      assertion = cfg.host.bootReviewed;
      message = ''
        This host was generated by ryoku-bootstrap and its boot loader settings
        have not been reviewed. Check hosts/${config.networking.hostName}/boot.nix
        against /etc/nixos/configuration.nix, then set
        ryoku.host.bootReviewed = true there.'';
    }
    {
      assertion = !cfg.hardware.nvidia.prime.enable || cfg.hardware.nvidia.enable;
      message = "ryoku.hardware.nvidia.prime.enable requires ryoku.hardware.nvidia.enable";
    }
    {
      assertion = !cfg.hardware.nvidia.prime.enable
        || (cfg.hardware.nvidia.prime.nvidiaBusId != null
          && (cfg.hardware.nvidia.prime.intelBusId != null || cfg.hardware.nvidia.prime.amdgpuBusId != null));
      message = "NVIDIA PRIME needs nvidiaBusId and intelBusId or amdgpuBusId (see `lspci -D`).";
    }
  ];
}
