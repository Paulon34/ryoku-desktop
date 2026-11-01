# Dev helper: nix build -f pkgs/sddm-ryoku-theme-build.nix
# Mirrors modules/desktop.nix theme wiring (no NixOS system).
{
  pkgs ? import (builtins.getFlake (toString ./..)).inputs.nixpkgs { system = "x86_64-linux"; },
  lib ? pkgs.lib,
}:

let
  ryokuLib = import ../ryoku/lib.nix { inherit lib; };
  ryokuLoginWallpaper = ryokuLib.loginWallpaper;
  ryokuLoginWallpaperPath = ryokuLib.loginWallpaperPath;

  astronautBase = pkgs.sddm-astronaut.override {
    embeddedTheme = "japanese_aesthetic";
  };

  defaultThemeBackground =
    "${astronautBase}/share/sddm/themes/sddm-astronaut-theme/Backgrounds/japanese_aesthetic.png";

  wallpaperForContrast =
    if ryokuLoginWallpaperPath != null then ryokuLoginWallpaperPath else defaultThemeBackground;

  contrast = pkgs.callPackage ./sddm-ryoku-contrast.nix {
    wallpaper = wallpaperForContrast;
  };

  readabilityThemeConfig =
    contrast.themeConfig
    // lib.optionalAttrs (ryokuLoginWallpaper != null && ryokuLoginWallpaperPath != null) {
      Background = "${ryokuLoginWallpaperPath}";
    };
in
(pkgs.sddm-astronaut.override {
  embeddedTheme = "japanese_aesthetic";
  themeConfig = readabilityThemeConfig;
}).overrideAttrs (old: {
  postInstall =
    (old.postInstall or "")
    + import ../modules/sddm/astronaut/overlay.nix { inherit (contrast) schemeName; }
    + ''
      printf '%s\n' '${builtins.toJSON contrast.luma}' > "$themeDir/ryoku-contrast-luma.json"
    '';
  passthru = (old.passthru or { }) // {
    ryokuContrast = contrast;
  };
})
