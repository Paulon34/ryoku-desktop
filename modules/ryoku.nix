{
  config,
  lib,
  pkgs,
  ...
}:

# Ryoku settings.json reader + applied marker (7G-A) + privileged apply (7G-B).
#
# Security model:
# - The GUI is unprivileged and never sends repo/host/command strings to root.
# - ryoku-settings-apply is allowlisted (apply|rollback|switch-generation <N>)
#   with fixed flake ref; GUI supplies only the allowlisted op (+ integer for switch).
# - Polkit (org.ryoku.settings.apply) is the authorization boundary.
# - Applied hash marker is written only by NixOS activation (environment.etc).

let
  ryokuLib = import ../ryoku/lib.nix { inherit lib; };

  cfg = config.ryoku.settingsApply;

  applyHelper = pkgs.callPackage ../pkgs/ryoku-settings-apply.nix {
    repoPath = cfg.repoPath;
    flakeHost = cfg.flakeHost;
  };

  # Same package as flake packages.ryoku-settings — single installation source.
  # Bake repoPath so launcher/cwd-independent launches resolve the Ryoku repo.
  settingsGui = pkgs.callPackage ../pkgs/ryoku-settings.nix {
    ryokuRepoPathDefault = cfg.repoPath;
    ryokuFlakeHostDefault = cfg.flakeHost;
  };

  polkitAction = pkgs.writeTextFile {
    name = "org.ryoku.settings.apply.policy";
    text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE policyconfig PUBLIC
       "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
       "http://www.freedesktop.org/standards/PolicyKit/1.0/policyconfig.dtd">
      <policyconfig>
        <vendor>Ryoku</vendor>
        <vendor_url>https://github.com/Paulon34</vendor_url>

        <action id="org.ryoku.settings.apply">
          <description>Apply or switch Ryoku system configuration</description>
          <description xml:lang="pt_BR">Aplicar ou trocar configuração do sistema Ryoku</description>
          <message>Authentication is required to apply or switch Ryoku system generations.</message>
          <message xml:lang="pt_BR">É necessária autenticação para aplicar ou trocar gerações do sistema Ryoku.</message>
          <defaults>
            <allow_any>no</allow_any>
            <allow_inactive>auth_admin</allow_inactive>
            <allow_active>auth_admin</allow_active>
          </defaults>
          <annotate key="org.freedesktop.policykit.exec.path">${lib.getExe applyHelper}</annotate>
        </action>
      </policyconfig>
    '';
    destination = "/share/polkit-1/actions/org.ryoku.settings.apply.policy";
  };
in
{
  options.ryoku = {
    settings = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = ryokuLib.settings;
      description = ''
        Parsed ryoku/settings.json (schemaVersion ${toString ryokuLib.supportedSchemaVersion}).
        Source of truth for migrated Ryoku Settings keys. null values mean
        "do not override" existing NixOS/HM/DMS configuration.
      '';
    };

    settingsHash = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = ryokuLib.settingsHash;
      description = ''
        SHA-256 of the declarative apply subset (see ryoku/lib.nix applySubset).
        Written to /etc/ryoku/applied-settings-hash on activation.
      '';
    };

    settingsApply = {
      enable = lib.mkEnableOption "Ryoku Settings privileged apply helper (Polkit)" // {
        default = true;
      };

      repoPath = lib.mkOption {
        type = lib.types.str;
        default = "/home/${config.ryoku.user.name}/ryoku";
        defaultText = lib.literalExpression ''"/home/''${config.ryoku.user.name}/ryoku"'';
        description = ''
          Absolute path to the Ryoku flake repository. Fixed in the privileged
          helper at build time — the GUI cannot override this.
        '';
      };

      flakeHost = lib.mkOption {
        type = lib.types.strMatching "[A-Za-z0-9_-]+";
        default = config.networking.hostName;
        defaultText = lib.literalExpression "config.networking.hostName";
        description = ''
          NixOS flake host attribute (hosts/<name> → .#<name>). Fixed in the
          privileged helper and in Ryoku Settings at build time.
        '';
      };
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
          apps
          desktop
          hyprland
          flatpakDeclared
          loginWallpaper
          loginWallpaperPath
          pointerCursor
          shellStyle
          applySubset
          settingsHash
          applyInventory
          ;
      };
      description = "Helpers for projecting Ryoku settings into NixOS modules.";
      visible = false;
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = config.ryoku.settings.schemaVersion == ryokuLib.supportedSchemaVersion;
          message = "ryoku.settings.schemaVersion mismatch";
        }
        {
          assertion = builtins.substring 0 1 cfg.repoPath == "/";
          message = "ryoku.settingsApply.repoPath must be an absolute path";
        }
      ];

      # Marker for Ryoku Settings ApplyController.
      # Updated only when this NixOS generation is activated — never by the GUI.
      environment.etc."ryoku/applied-settings-hash".text = "${ryokuLib.settingsHash}\n";

      # Static Ryoku metadata (no services). Distinct generation fingerprint.
      environment.etc."ryoku/version".text = ''
        Ryoku Desktop Experience
        schemaVersion=${toString ryokuLib.supportedSchemaVersion}
      '';

      # Ryoku Settings GUI — declarative install (desktop entry + binary).
      # Always on when this module is imported; independent of Polkit apply helper.
      environment.systemPackages = [ settingsGui ];
    }

    (lib.mkIf cfg.enable {
      environment.systemPackages = [
        applyHelper
        polkitAction
      ];

      # Absolute helper path for the unprivileged GUI (bootstrap detection).
      environment.etc."ryoku/settings-apply-helper".text = "${lib.getExe applyHelper}\n";
    })
  ];
}
