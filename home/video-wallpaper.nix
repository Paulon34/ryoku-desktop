{ pkgs, lib, ... }:

# Video wallpaper renderer (mpvpaper) for Ryoku Settings.
#
# The unit is static; the selected video is runtime state written by
# `ryoku-video-wallpaper apply` to ~/.local/state/ryoku/video-wallpaper.env
# (same live model as static wallpapers via DMS IPC — no rebuild per change).
# Without that file the unit does not start, so mpvpaper only runs while a
# video wallpaper is selected.

let
  videoWallpaper = pkgs.callPackage ../pkgs/ryoku-video-wallpaper.nix { };
  helper = lib.getExe videoWallpaper;
in
{
  home.packages = [ videoWallpaper ];

  systemd.user.services.ryoku-video-wallpaper = {
    Unit = {
      Description = "Ryoku video wallpaper (mpvpaper)";
      PartOf = [ "graphical-session.target" ];
      # DMS first: it restores the poster/palette before the video covers it.
      After = [
        "graphical-session.target"
        "dms.service"
      ];
      ConditionPathExists = "%S/ryoku/video-wallpaper.env";
      # Crash guard: at most 3 starts per minute, then the unit stays failed
      # and ExecStopPost has already put the static DMS wallpaper back.
      StartLimitIntervalSec = 60;
      StartLimitBurst = 3;
    };

    Service = {
      Type = "simple";
      EnvironmentFile = "%S/ryoku/video-wallpaper.env";
      # Missing/moved video → unit skipped (not failed, no restart loop).
      ExecCondition = "${helper} check";
      ExecStart = "${helper} run";
      # mpvpaper has no readiness signal; hide the DMS layer once the video
      # surface is up so the desktop never shows an empty background.
      ExecStartPost = [
        "${pkgs.coreutils}/bin/sleep 1.5"
        "${helper} dms-hide"
      ];
      ExecStopPost = "${helper} dms-restore";
      Restart = "on-failure";
      RestartSec = 3;
      TimeoutStopSec = 5;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
