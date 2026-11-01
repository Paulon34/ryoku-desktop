{
  lib,
  writeShellApplication,
  coreutils,
  gnugrep,
  gnused,
  pciutils,
  systemd,
}:

# scripts/ryoku-bootstrap packaged with its tools; shellcheck runs at build.
writeShellApplication {
  name = "ryoku-bootstrap";
  runtimeInputs = [
    coreutils
    gnugrep
    gnused
    pciutils
    systemd
  ];
  text = builtins.readFile ../scripts/ryoku-bootstrap;
  meta = {
    description = "Write a reviewable Ryoku host for an existing NixOS installation";
    license = lib.licenses.mit;
    mainProgram = "ryoku-bootstrap";
  };
}
