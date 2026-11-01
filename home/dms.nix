{ config, osConfig, pkgs, lib, ... }:

let
  # Weather place from ryoku/settings.json (weather.location). DMS resolves it
  # with its own Open-Meteo geocoding; null keeps weather off, so the DMS
  # default city is never fetched.
  weatherLocation = config.ryoku.lib.weatherLocation;

  # "quattro" (default) or "islands"; the DMS build reads the same value.
  quattro = config.ryoku.lib.shellStyle == "quattro";

  # The patched DMS the system runs (modules/desktop.nix); its CLI reaches the
  # running instance, which is keyed by this package's config path.
  dmsPackage = osConfig.programs.dms-shell.package;

  # Style-specific DMS preferences. Quattro follows Omarchy Quattro's shell
  # look: small radius shared with Hyprland, near-opaque flat cards (no blur
  # needed over the video wallpaper), list power menu, no notification shadow.
  styleSettings =
    if quattro then
      {
        cornerRadius = 8;
        popupTransparency = 0.97;
        notificationPopupShadowEnabled = false;
        # QML draws the gradient frame; a second DMS border would double it.
        dankLauncherV2BorderEnabled = false;
        modalDarkenBackground = true;
        powerMenuGridLayout = false;
        lockScreenShowProfileImage = false;
        # The menu slot carries the system mark, as Omarchy's does.
        launcherLogoMode = "os";
        launcherLogoColorOverride = "primary";
      }
    else
      {
        cornerRadius = 16;
        launcherLogoMode = "apps";
        launcherLogoColorOverride = "";
        # Restore what Quattro turns off, so switching back is symmetric.
        notificationPopupShadowEnabled = true;
        lockScreenShowProfileImage = true;
        # Controlled glass: popouts/OSD/notifications let the existing compositor blur through.
        popupTransparency = 0.88;
      };

  # Default bar (barConfigs[id=default]) per style. Quattro: one slim strip
  # attached to the top edge, widgets straight on it (no pills), Omarchy's
  # left/center/right distribution. Islands: the floating capsules.
  styleBar =
    if quattro then
      {
        noBackground = false;
        transparency = 0.96;
        widgetTransparency = 0;
        spacing = 0;
        innerPadding = 1;
        widgetPadding = 6;
        fontScale = 1.1;
        squareCorners = true;
        gothCornersEnabled = false;
        borderEnabled = false;
        widgetOutlineEnabled = false;
        shadowIntensity = 0;
        # Panels hang half of Hyprland's gaps_out below the strip.
        popupGapsAuto = false;
        popupGapsManual = 5;
        leftWidgets = [ "launcherButton" "workspaceSwitcher" ];
        # Media Island stays a CenterSection overlay beside the clock.
        centerWidgets = [ "clock" ];
        rightWidgets = [
          "systemTray"
          "notificationButton"
          "controlCenterButton"
          "battery"
        ];
      }
    else
      {
        noBackground = true;
        transparency = 1;
        widgetTransparency = 0.92;
        spacing = 10;
        innerPadding = 4;
        widgetPadding = 6;
        fontScale = 1;
        squareCorners = false;
        borderEnabled = false;
        widgetOutlineEnabled = false;
        shadowIntensity = 0;
        popupGapsAuto = true;
        leftWidgets = [ "launcherButton" "workspaceSwitcher" "focusedWindow" ];
        # Clock stays sole center widget — Media Island is a CenterSection
        # overlay (Phases 5A–5C + central-island unify) so clock geometry
        # never shifts when media appears/resizes. Shared capsule uses a
        # left spacer matching media width to keep the clock screen-centered.
        # Stock Media.qml / showMusic / CAVA stay off.
        centerWidgets = [ "clock" ];
        rightWidgets = [
          "systemTray"
          "notificationButton"
          "battery"
          "controlCenterButton"
        ];
      };

  # Declarative Ryoku bar preferences applied onto mutable DMS settings.json.
  # Keys are from DMS 1.5.3 SettingsSpec / barConfigs defaults — not invented.
  ryokuBarPatch = pkgs.writeText "ryoku-dms-bar-patch.json" (builtins.toJSON (styleSettings // {
    widgetBackgroundColor = "sc"; # surfaceContainer — pill fills from Matugen
    workspaceColorMode = "primary";
    focusedWindowCompactMode = true;
    focusedWindowSize = 0; # smallest title budget (SettingsSpec)
    clockCompactMode = false;
    showSeconds = false;
    showWorkspaceIndex = false;
    showWorkspaceApps = false;
    showWorkspaceName = false;
    barElevationEnabled = false;
    showMusic = false;
    showWeather = false;
    showCpuUsage = false;
    showMemUsage = false;
    showClipboard = false;
    # Keep launcher / workspaces / clock / tray / notif / battery / QS entry points.
    showLauncherButton = true;
    showWorkspaceSwitcher = true;
    showFocusedWindow = true;
    showClock = true;
    showSystemTray = true;
    showNotificationButton = true;
    showBattery = true;
    showControlCenterButton = true;
    animationSpeed = 1;
    popoutAnimationSpeed = 1;
    syncComponentAnimationSpeeds = true;
    # M3WaveProgress redraws every frame while media plays; keep the flat seekbar.
    waveProgressEnabled = false;
    # Weather is owned by ryoku/settings.json: no IP/geoclue lookup.
    weatherEnabled = weatherLocation != null;
    useAutoLocation = false;
  }));

  # appearance.wallpaper, installed by home/theme.nix under ~/.local/share/wallpapers.
  defaultWallpaper =
    let
      w = config.ryoku.lib.wallpaper;
    in
    if w == null then "" else "${config.home.homeDirectory}/.local/share/wallpapers/${w}";

  ryokuDefaultBar = pkgs.writeText "ryoku-dms-default-bar.json" (builtins.toJSON styleBar);

  # Empty coordinates make DMS geocode weatherLocation by name.
  ryokuWeatherSession = pkgs.writeText "ryoku-dms-weather-session.json" (builtins.toJSON {
    weatherLocation = if weatherLocation == null then "" else weatherLocation;
    weatherCoordinates = "";
  });

  # dms_ipc ARGS…: call the running DMS, waiting up to 60 s for its IPC (on a
  # first login dms.service is still "activating" when these scripts run).
  # Returns 1 when DMS is not running or never answers.
  dmsIpcHelper = ''
    dms_ipc() {
      [ -n "''${XDG_RUNTIME_DIR:-}" ] || return 1
      for _ in $(${pkgs.coreutils}/bin/seq 120); do
        case "$(${pkgs.systemd}/bin/systemctl --user is-active dms.service 2>/dev/null || true)" in
          active | activating | reloading) ;;
          *) return 1 ;;
        esac
        if ${dmsPackage}/bin/dms ipc call "$@" >/dev/null 2>&1; then
          return 0
        fi
        ${pkgs.coreutils}/bin/sleep 0.5
      done
      return 1
    }
  '';

  applyRyokuWeather = pkgs.writeShellScript "apply-ryoku-dms-weather" ''
    set -euo pipefail
    ${dmsIpcHelper}

    session="''${XDG_STATE_HOME:-$HOME/.local/state}/DankMaterialShell/session.json"
    jq=${lib.getExe pkgs.jq}

    if [ ! -f "$session" ]; then
      echo "Ryoku DMS: session.json missing; skipping weather location" >&2
      exit 0
    fi

    # First session only: DMS has no wallpaper yet, so start from the Ryoku one
    # (appearance.wallpaper). Afterwards the wallpaper is the user's.
    wallpaper=${lib.escapeShellArg defaultWallpaper}
    if [ -n "$wallpaper" ] && [ -f "$wallpaper" ] \
      && [ -z "$("$jq" -r '.wallpaperPath // ""' "$session")" ]; then
      wallpaperJson=$("$jq" -n --arg w "$wallpaper" '{wallpaperPath: $w}')
    else
      wallpaperJson='{}'
    fi

    "$jq" -s '.[0] + .[1] + .[2]' "$session" ${ryokuWeatherSession} <(printf '%s' "$wallpaperJson") > "$session.tmp"
    mv "$session.tmp" "$session"

    # A running DMS already loaded its wallpaper; hand it the first one live.
    if [ "$wallpaperJson" != '{}' ]; then
      dms_ipc wallpaper set "$wallpaper" && echo "Ryoku DMS: first wallpaper set" || true
    fi
  '';

  applyRyokuBar = pkgs.writeShellScript "apply-ryoku-dms-bar" ''
    set -euo pipefail
    ${dmsIpcHelper}

    settings="$HOME/.config/DankMaterialShell/settings.json"
    patch=${ryokuBarPatch}
    jq=${lib.getExe pkgs.jq}

    mkdir -p "$HOME/.config/DankMaterialShell"

    if [ ! -f "$settings" ]; then
      echo "Ryoku DMS: settings.json missing; skipping bar patch" >&2
      exit 0
    fi

    before=$(${pkgs.coreutils}/bin/sha256sum < "$settings")

    # Merge top-level appearance flags + rewrite default bar widget layout.
    "$jq" -s '
      .[0] as $s | .[1] as $p | .[2] as $bar |
      ($s + $p) |
      .barConfigs = (
        (.barConfigs // []) | map(if .id == "default" then . + $bar else . end)
      )
    ' "$settings" "$patch" ${ryokuDefaultBar} > "$settings.tmp"

    mv "$settings.tmp" "$settings"

    changed=1
    [ "$(${pkgs.coreutils}/bin/sha256sum < "$settings")" != "$before" ] || changed=0

    # A running DMS keeps the bar it loaded at start and does not see this
    # rename; a switch restarts dms.service moments before this activation, so
    # it would keep the previous style's bar. Always ask it to re-read the file
    # (idempotent); if its IPC is not up yet and the file changed, restart it
    # so it starts from the new file.
    if dms_ipc ryoku refreshSettings; then
      echo "Ryoku DMS: running shell reloaded settings.json"
    elif [ "$changed" = 1 ] && ${pkgs.systemd}/bin/systemctl --user is-active --quiet dms.service 2>/dev/null; then
      echo "Ryoku DMS: IPC unavailable; restarting dms.service" >&2
      ${pkgs.systemd}/bin/systemctl --user try-restart dms.service || true
    fi
  '';
in
{
  # Quickshell 0.3.0 does not rescan DesktopEntries on demand. Coalesce the
  # writes made by application installers, then restart DMS only when it is
  # already running so its launcher rebuilds the desktop-entry catalogue.
  systemd.user.paths.ryoku-desktop-entries-refresh = {
    Unit.Description = "Watch user desktop entries for DMS launcher refresh";
    Path = {
      PathChanged = "%h/.local/share/applications";
      Unit = "ryoku-desktop-entries-refresh.service";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.ryoku-desktop-entries-refresh = {
    Unit.Description = "Refresh DMS launcher after desktop entry changes";
    Service = {
      Type = "oneshot";
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 2";
      ExecStart = "${pkgs.systemd}/bin/systemctl --user try-restart dms.service";
    };
  };

  # DMS writes settings.json / session.json on its first start, after the
  # activation below has already skipped them. Apply the Ryoku layer as soon as
  # they exist, and again at each login (idempotent; also re-syncs a running
  # DMS that loaded an older file).
  systemd.user.paths.ryoku-dms-bar = {
    Unit.Description = "Apply the Ryoku bar to DMS once its settings exist";
    Path.PathExists = "%h/.config/DankMaterialShell/settings.json";
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.ryoku-dms-bar = {
    Unit.Description = "Apply the Ryoku bar and shell style to DMS";
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${applyRyokuBar}";
    };
  };

  systemd.user.paths.ryoku-dms-session = {
    Unit.Description = "Apply Ryoku weather/wallpaper to DMS once its session exists";
    Path.PathExists = "%S/DankMaterialShell/session.json";
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.ryoku-dms-session = {
    Unit.Description = "Apply the Ryoku weather location and first wallpaper to DMS";
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${applyRyokuWeather}";
    };
  };

  # Subset of DMS bar config for Ryoku. File stays mutable; we only merge keys.
  home.activation.applyRyokuDmsBar =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${applyRyokuBar}
    '';

  # session.json is watched by DMS, so the new location applies without restart.
  home.activation.applyRyokuDmsWeather =
    lib.hm.dag.entryAfter [ "applyRyokuDmsBar" ] ''
      run ${applyRyokuWeather}
    '';
}
