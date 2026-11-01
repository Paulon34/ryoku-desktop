{
  lib,
  stdenv,
  cmake,
  nix,
  nixos-rebuild,
  repoPath,
  flakeHost,
}:

assert builtins.isString repoPath && repoPath != "";
assert builtins.substring 0 1 repoPath == "/"; # absolute path required

stdenv.mkDerivation {
  pname = "ryoku-settings-apply";
  version = "0.1.0";

  src = ../apps/ryoku-settings-apply;

  nativeBuildInputs = [ cmake ];

  cmakeFlags = [
    "-DRYOKU_REPO_PATH=${repoPath}"
    "-DRYOKU_FLAKE_HOST=${flakeHost}"
    "-DRYOKU_NIXOS_REBUILD=${lib.getExe nixos-rebuild}"
    "-DRYOKU_NIX_ENV=${lib.getExe' nix "nix-env"}"
  ];

  meta = {
    description = "Privileged Ryoku Settings apply/rollback/switch-generation helper (Polkit)";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "ryoku-settings-apply";
  };
}
