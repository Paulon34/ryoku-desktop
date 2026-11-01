{ pkgs, lib, config, ... }:

let
  appImage = "${config.home.homeDirectory}/AppImages/scrcpy_gui.appimage";
  iconPath = "${config.home.homeDirectory}/AppImages/.icons/scrcpy_gui";
  appimageRun = lib.getExe pkgs.appimage-run;

  patchScrcpyGuiConfig = pkgs.writeShellScript "patch-scrcpy-gui-config" ''
    set -euo pipefail

    config_dir="$HOME/.config/scrcpy-gui"
    wrapper="$HOME/.local/bin/scrcpy-nixos"
    config_file="$config_dir/config.json"
    backup_file="$config_dir/config.backup.json"
    jq=${lib.getExe pkgs.jq}

    mkdir -p "$config_dir"

    patch_scrcpy_path() {
      local file="$1"
      local create_if_missing="$2"

      if [ ! -f "$file" ]; then
        if [ "$create_if_missing" = "yes" ]; then
          "$jq" -n --arg p "$wrapper" '{
            schemaVersion: 3,
            runtime: {
              mode: "custom",
              customScrcpyPath: $p
            }
          }' > "$file"
        fi
        return 0
      fi

      "$jq" --arg p "$wrapper" '
        .runtime = (.runtime // {})
        | .runtime.mode = "custom"
        | .runtime.customScrcpyPath = $p
      ' "$file" > "$file.tmp"
      mv "$file.tmp" "$file"
    }

    patch_scrcpy_path "$config_file" yes
    patch_scrcpy_path "$backup_file" no
  '';
in
{
  # Versioned wrapper (same pattern as change-wallpaper).
  home.file.".local/bin/scrcpy-nixos" = {
    source = ../scripts/scrcpy-nixos;
    executable = true;
  };

  # CLI helper: phone camera → /dev/video2 (v4l2loopback).
  home.file.".local/bin/scrcpy-webcam" = {
    source = ../scripts/scrcpy-webcam;
    executable = true;
  };

  # Declarative launcher; AppImage stays under ~/AppImages for now.
  xdg.desktopEntries.scrcpy_gui = {
    name = "Scrcpy GUI";
    comment = "A modern, secure desktop GUI for scrcpy";
    icon = iconPath;
    exec = "${appimageRun} ${appImage} --no-sandbox %U";
    terminal = false;
    categories = [ "Utility" ];
    settings = {
      StartupWMClass = "scrcpy-gui";
      TryExec = appimageRun;
      X-AppImage-Name = "Scrcpy GUI";
    };
  };

  # Keep configs mutable: only merge runtime.customScrcpyPath (+ mode).
  home.activation.setScrcpyGuiCustomPath =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${patchScrcpyGuiConfig}
    '';
}
