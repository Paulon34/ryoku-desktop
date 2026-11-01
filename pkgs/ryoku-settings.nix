{
  lib,
  stdenv,
  cmake,
  qt6,
  git,
  wireplumber,
  hyprland,
  brightnessctl,
  nix,
  desktop-file-utils,
  callPackage,
  ryokuRepoPathDefault ? "",
  ryokuFlakeHostDefault ? "",
}:

let
  videoWallpaper = callPackage ./ryoku-video-wallpaper.nix { };
in
stdenv.mkDerivation {
  pname = "ryoku-settings";
  version = "0.1.0-dev";

  src = ../apps/ryoku-settings;

  nativeBuildInputs = [
    cmake
    qt6.wrapQtAppsHook
    qt6.qttools
  ];

  # Validate installed desktop entry (not a runtime dep).
  nativeInstallCheckInputs = [ desktop-file-utils ];
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    desktop-file-validate "$out/share/applications/org.ryoku.Settings.desktop"
    test -x "$out/bin/ryoku-settings"
    grep -q '^Exec=ryoku-settings$' "$out/share/applications/org.ryoku.Settings.desktop"
    grep -q '^Terminal=false$' "$out/share/applications/org.ryoku.Settings.desktop"
    grep -q '^Icon=org.ryoku.Settings$' "$out/share/applications/org.ryoku.Settings.desktop"
    grep -q '^StartupWMClass=org.ryoku.Settings$' "$out/share/applications/org.ryoku.Settings.desktop"
    test -f "$out/share/icons/hicolor/scalable/apps/org.ryoku.Settings.svg"
    if grep -q '^X-GNOME-Autostart' "$out/share/applications/org.ryoku.Settings.desktop"; then
      echo "desktop entry must not enable autostart" >&2
      exit 1
    fi
    runHook postInstallCheck
  '';

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtwayland
    qt6.qtsvg
  ];

  cmakeFlags = [
    "-DRYOKU_SETTINGS_BUILD_TESTS=OFF"
  ]
  ++ lib.optional (ryokuRepoPathDefault != "")
    "-DRYOKU_REPO_PATH_DEFAULT=${ryokuRepoPathDefault}"
  ++ lib.optional (ryokuFlakeHostDefault != "")
    "-DRYOKU_FLAKE_HOST_DEFAULT=${ryokuFlakeHostDefault}";

  # Runtime tools via QProcess argv (no shell):
  # - git, wpctl, hyprctl, brightnessctl, nix, ryoku-video-wallpaper
  # - nixos-rebuild comes from the NixOS system profile PATH
  # pkexec is intentionally NOT from pkgs.polkit — NixOS requires
  # /run/wrappers/bin/pkexec (setuid/capability wrapper).
  qtWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [ git wireplumber hyprland brightnessctl nix videoWallpaper ])
  ];

  # CMake installs bin/ryoku-settings + desktop entry + hicolor icons.
  # Canonical icon name: org.ryoku.Settings (placeholder SVG until final art).

  meta = {
    description = "Ryoku Settings — desktop configuration with privileged Apply";
    homepage = "https://github.com/Paulon34";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "ryoku-settings";
  };
}
