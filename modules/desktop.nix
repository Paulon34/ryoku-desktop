{ config, pkgs, lib, inputs, ... }:

let
  # SDDM astronaut + Ryoku adaptive contrast (wallpaper luminance → themeConfig).
  ryokuLoginWallpaper = config.ryoku.lib.loginWallpaper or null;
  ryokuLoginWallpaperPath = config.ryoku.lib.loginWallpaperPath or null;

  # Unpatched astronaut — used as default wallpaper source when loginWallpaper is null.
  astronautBase = pkgs.sddm-astronaut.override {
    embeddedTheme = "japanese_aesthetic";
  };

  defaultThemeBackground =
    "${astronautBase}/share/sddm/themes/sddm-astronaut-theme/Backgrounds/japanese_aesthetic.png";

  wallpaperForContrast =
    if ryokuLoginWallpaperPath != null then ryokuLoginWallpaperPath else defaultThemeBackground;

  contrast = pkgs.callPackage ../pkgs/sddm-ryoku-contrast.nix {
    wallpaper = wallpaperForContrast;
  };

  readabilityThemeConfig =
    contrast.themeConfig
    // lib.optionalAttrs (ryokuLoginWallpaper != null && ryokuLoginWallpaperPath != null) {
      Background = "${ryokuLoginWallpaperPath}";
    };

  sddmAstronautTheme =
    (pkgs.sddm-astronaut.override {
      embeddedTheme = "japanese_aesthetic";
      themeConfig = readabilityThemeConfig;
    }).overrideAttrs (old: {
      # Visual-only overlays — glass card, clean clock, tonal buttons/inputs.
      postInstall =
        (old.postInstall or "")
        + import ./sddm/astronaut/overlay.nix { inherit (contrast) schemeName; };
    });

  # Greeter searches XCURSOR_PATH (pam_env → /run/current-system/sw/share/icons).
  # A missing theme only falls back to the X core cursor; SDDM still starts.
  ryokuCursor = config.ryoku.lib.pointerCursor;
  ryokuCursorPackage = pkgs.${ryokuCursor.package};

  nvidia = config.ryoku.hardware.nvidia;
in
{
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  programs.hyprland.enable = true;
services.xserver.enable = true;

services.displayManager.sddm = {
  enable = true;
  wayland.enable = false;

  theme = "sddm-astronaut-theme";

  # [General] Numlock=on — the X11 greeter starts with NumLock enabled.
  autoNumlock = true;

  extraPackages = [
    sddmAstronautTheme
  ];

  settings.Theme = {
    CursorTheme = ryokuCursor.name;
    CursorSize = ryokuCursor.size;
  };
};

# Qt6 xcb (xcb-util-cursor) ignores XCURSOR_THEME and the greeter has no
# Xcursor.theme resource, so CursorTheme alone yields the X core cursor.
# Without a resource it loads the "default" theme, which inherits ours.
xdg.icons.fallbackCursorThemes = [ ryokuCursor.name ];

 security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  environment.systemPackages = with pkgs; [

    firefox
mesa-demos

libnotify

    kitty

    waybar
    rofi
    mako

    hyprpaper
    hyprlock
    hypridle

    wl-clipboard
    cliphist

matugen

sddmAstronautTheme
ryokuCursorPackage

    grim
    slurp
    swappy

    pavucontrol
    playerctl

    brightnessctl

    networkmanagerapplet

    kdePackages.dolphin
    kdePackages.ark

    polkit_gnome
  ] ++ lib.optionals config.ryoku.features.apps [
    discord
  ];

# GPU drivers come from ryoku.hardware (set by the host; the bootstrap only
# suggests them). modesetting covers Intel/AMD; NVIDIA is opt-in.
services.xserver.videoDrivers = lib.mkIf nvidia.enable [
  "modesetting"
  "nvidia"
];

# VA-API for Intel iGPUs (iHD). Video wallpaper (mpvpaper hwdec=vaapi)
# decodes here instead of waking an offload dGPU or falling back to CPU.
hardware.graphics.extraPackages = lib.mkIf config.ryoku.hardware.intelVideoAcceleration [ pkgs.intel-media-driver ];

hardware.nvidia = lib.mkIf nvidia.enable {
  open = nvidia.open;

  modesetting.enable = true;
  powerManagement.enable = true;

  prime = lib.mkIf nvidia.prime.enable ({
    offload = {
      enable = true;
      enableOffloadCmd = true;
    };
  }
  // lib.optionalAttrs (nvidia.prime.intelBusId != null) { inherit (nvidia.prime) intelBusId; }
  // lib.optionalAttrs (nvidia.prime.amdgpuBusId != null) { inherit (nvidia.prime) amdgpuBusId; }
  // lib.optionalAttrs (nvidia.prime.nvidiaBusId != null) { inherit (nvidia.prime) nvidiaBusId; });
};

fonts.packages = with pkgs; [
  inter
  fira-code
];

programs.dms-shell = {
  enable = true;

  # Ryoku floating bar + Control Center polish — QML patches pinned to DMS 1.5.3.
  # Rebuild fails clearly if the package version or QML context drifts.
  package = pkgs.dms-shell.overrideAttrs (old: {
    postInstall =
      old.postInstall
      + ''
        if [ "${old.version}" != "1.5.3" ]; then
          echo "error: Ryoku DMS patches are pinned to dms-shell 1.5.3 (got ${old.version})" >&2
          exit 1
        fi
        echo "Applying Ryoku DMS patches for ${old.version}..."
        chmod -R u+w "$out/share/quickshell/dms"
        ${pkgs.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" \
          < ${../patches/dms/1.5.3/ryoku-bar-islands.patch}
        ${pkgs.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" \
          < ${../patches/dms/1.5.3/ryoku-bar-polish.patch}
        ${pkgs.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" \
          < ${../patches/dms/1.5.3/ryoku-bar-media-island.patch}
        ${pkgs.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" \
          < ${../patches/dms/1.5.3/ryoku-bar-central-island.patch}
        ${pkgs.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" \
          < ${../patches/dms/1.5.3/ryoku-control-center.patch}
        ${pkgs.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" \
          < ${../patches/dms/1.5.3/ryoku-dankdash.patch}
        ${pkgs.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" \
          < ${../patches/dms/1.5.3/ryoku-shell-polish.patch}
        ${pkgs.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" \
          < ${../patches/dms/1.5.3/ryoku-notifications.patch}
        ${pkgs.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" \
          < ${../patches/dms/1.5.3/ryoku-tray-osd-blur.patch}
        ${pkgs.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" \
          < ${../patches/dms/1.5.3/ryoku-launcher.patch}
        ${pkgs.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" \
          < ${../patches/dms/1.5.3/ryoku-weather.patch}
        ${pkgs.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" \
          < ${../patches/dms/1.5.3/ryoku-bluetooth-empty-state.patch}
        ${pkgs.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" \
          < ${../patches/dms/1.5.3/ryoku-dankdash-polish.patch}
        ${pkgs.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" \
          < ${../patches/dms/1.5.3/ryoku-visual-profile.patch}
        ${pkgs.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" \
          < ${../patches/dms/1.5.3/ryoku-popout-depth.patch}
        ${pkgs.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" \
          < ${../patches/dms/1.5.3/ryoku-notifications-copy-dnd.patch}
        # Quattro shell style (after Omarchy Quattro): tokens and frame, bar,
        # panels, launcher/menus, notifications/OSD, lock. Inert under "islands".
        ${pkgs.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" \
          < ${../patches/dms/1.5.3/ryoku-quattro-foundation.patch}
        ${pkgs.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" \
          < ${../patches/dms/1.5.3/ryoku-quattro-bar.patch}
        ${pkgs.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" \
          < ${../patches/dms/1.5.3/ryoku-quattro-panels.patch}
        ${pkgs.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" \
          < ${../patches/dms/1.5.3/ryoku-quattro-launcher-menus.patch}
        ${pkgs.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" \
          < ${../patches/dms/1.5.3/ryoku-quattro-notifications-osd.patch}
        ${pkgs.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" \
          < ${../patches/dms/1.5.3/ryoku-quattro-lock.patch}
        # First run: persist DMS defaults so home/dms.nix can apply the Ryoku bar.
        ${pkgs.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" \
          < ${../patches/dms/1.5.3/ryoku-first-run.patch}
        # RyokuVisual watches ryoku/settings.json (visual profile) at runtime;
        # the shell style is fixed per build (appearance.shellStyle).
        substituteInPlace "$out/share/quickshell/dms/Common/RyokuVisual.qml" \
          --replace-fail "@RYOKU_SETTINGS_JSON@" \
          "${config.ryoku.settingsApply.repoPath}/ryoku/settings.json" \
          --replace-fail "@RYOKU_SHELL_STYLE@" \
          "${config.ryoku.lib.shellStyle}"
      '';
  });

  systemd = {
    enable = true;
    restartIfChanged = true;
  };
};

}
