{ config, lib, ... }:

# Flatpak packages are declared solely in ryoku/settings.json
# (apps.flatpakDeclared). This module only projects that list to nix-flatpak.
# Do not hardcode application IDs here.

let
  ryokuApps = config.ryoku.settings.apps or { };
  declared = ryokuApps.flatpakDeclared or [ ];

  allStrings =
    builtins.all (x: builtins.isString x && x != "") declared;
in
{
  assertions = [
    {
      assertion = builtins.isList declared;
      message = "ryoku.settings.apps.flatpakDeclared must be a list";
    }
    {
      assertion = allStrings;
      message = "ryoku.settings.apps.flatpakDeclared entries must be non-empty strings";
    }
  ];

  # Flatpak daemon is enabled in modules/services.nix (ryoku.features.flatpak).
  # nix-flatpak (flake input) adds Flathub by default when remotes are unset.
  services.flatpak.packages = lib.mkIf config.ryoku.features.flatpak declared;
}
