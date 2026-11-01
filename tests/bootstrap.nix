{
  lib,
  runCommand,
  nix,
  ryoku-bootstrap,
}:

# Runs scripts/ryoku-bootstrap against fake machines (RYOKU_SYSROOT fixtures):
# detection, dry-run, confirmation, overwrite refusal, non-NixOS refusal and
# that the generated Nix parses. No network, no real hardware.

runCommand "ryoku-bootstrap-test" { nativeBuildInputs = [ nix ]; } ''
  set -euo pipefail
  export HOME=$TMPDIR NIX_STATE_DIR=$TMPDIR/nix NIX_LOG_DIR=$TMPDIR/nix-log
  bs=${lib.getExe ryoku-bootstrap}

  fail() { echo "FAIL: $*" >&2; exit 1; }
  expect() { grep -qF -- "$2" "$1" || { echo "--- $1"; cat "$1"; fail "missing: $2"; }; }
  reject() { if grep -qF -- "$2" "$1"; then cat "$1"; fail "unexpected: $2"; fi; }

  mkrepo() {
    mkdir -p "$1/modules" "$1/ryoku" "$1/hosts"
    touch "$1/flake.nix" "$1/modules/options.nix"
    echo '{ "schemaVersion": 1 }' > "$1/ryoku/settings.json"
  }

  # ── Fixture A: hybrid Intel + NVIDIA laptop, systemd-boot, UEFI ─────────
  A=$TMPDIR/laptop
  mkdir -p $A/etc/nixos $A/proc $A/sys/class/dmi/id $A/sys/class/power_supply/BAT0 \
    $A/sys/class/net/wlp0s20f3/wireless $A/sys/class/bluetooth/hci0 \
    $A/sys/class/drm/card1-eDP-1 $A/sys/class/drm/card1-HDMI-A-1 \
    $A/sys/firmware/efi $A/boot/loader
  touch $A/etc/NIXOS $A/boot/loader/loader.conf
  echo "laptop-a" > $A/etc/hostname
  echo "alice:x:1000:100:Alice Doe,,,:/home/alice:/run/current-system/sw/bin/bash" > $A/etc/passwd
  printf 'vendor_id\t: GenuineIntel\nmodel name\t: Test CPU\n' > $A/proc/cpuinfo
  echo 10 > $A/sys/class/dmi/id/chassis_type
  echo Battery > $A/sys/class/power_supply/BAT0/type
  echo connected > $A/sys/class/drm/card1-eDP-1/status
  echo 2560x1600 > $A/sys/class/drm/card1-eDP-1/modes
  echo disconnected > $A/sys/class/drm/card1-HDMI-A-1/status
  echo 'LANG=en_US.UTF-8' > $A/etc/locale.conf
  echo 'KEYMAP=de' > $A/etc/vconsole.conf
  ln -s /etc/zoneinfo/Europe/Berlin $A/etc/localtime
  echo '{ ... }: { fileSystems."/" = { device = "/dev/disk/by-uuid/aaaa"; fsType = "ext4"; }; }' \
    > $A/etc/nixos/hardware-configuration.nix
  cat > $A/etc/nixos/configuration.nix <<'EOF'
  { ... }: {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    system.stateVersion = "25.11";
  }
  EOF
  cat > $TMPDIR/lspci-a <<'EOF'
  0000:00:02.0 VGA compatible controller [0300]: Intel Corporation TigerLake-LP GT2 [8086:9a49] (rev 01)
  0000:01:00.0 3D controller [0302]: NVIDIA Corporation TU117M [10de:1f9d] (rev a1)
  0000:00:14.3 Network controller [0280]: Intel Corporation Wi-Fi 6 [8086:a0f0]
  EOF
  sed -i 's/^  //' $TMPDIR/lspci-a $A/etc/nixos/configuration.nix

  R=$TMPDIR/repo; mkrepo $R
  run() { RYOKU_SYSROOT=$1 RYOKU_LSPCI=$2 RYOKU_ARCH=x86_64 USER=nobody "$bs" --repo $R "''${@:3}"; }

  # Dry run prints, writes nothing.
  run $A $TMPDIR/lspci-a --profile full --user alice --dry-run > $TMPDIR/a.out
  [ -z "$(ls -A $R/hosts)" ] || fail "dry run wrote files"
  expect $TMPDIR/a.out "hybrid graphics    yes"
  expect $TMPDIR/a.out "laptop (chassis type 10), battery: yes"
  expect $TMPDIR/a.out "Wi-Fi / Bluetooth  yes / yes"
  expect $TMPDIR/a.out "monitor            eDP-1 (2560x1600)"
  reject $TMPDIR/a.out "HDMI-A-1"
  expect $TMPDIR/a.out "Europe/Berlin / en_US.UTF-8 (keyboard: de)"
  expect $TMPDIR/a.out "UEFI / systemd-boot"
  expect $TMPDIR/a.out "Dry run: nothing was written."

  # Without --yes and without a terminal: refuses, writes nothing.
  if run $A $TMPDIR/lspci-a --profile full --user alice < /dev/null > $TMPDIR/a2.out 2>&1; then
    fail "wrote without confirmation"
  fi
  [ -z "$(ls -A $R/hosts)" ] || fail "files written without confirmation"

  # Confirmed write.
  run $A $TMPDIR/lspci-a --profile full --user alice --yes > $TMPDIR/a3.out
  H=$R/hosts/laptop-a
  for f in default.nix boot.nix home.nix hardware-configuration.nix; do [ -f $H/$f ] || fail "missing $f"; done
  cmp $H/hardware-configuration.nix $A/etc/nixos/hardware-configuration.nix || fail "hardware-configuration not copied verbatim"
  expect $H/default.nix 'name = "alice";'
  expect $H/default.nix 'description = "Alice Doe";'
  expect $H/default.nix 'profile = "full";'
  expect $H/default.nix 'hardware.intelVideoAcceleration = true;'
  expect $H/default.nix '#     intelBusId = "PCI:0@0:2:0";'
  expect $H/default.nix '#     nvidiaBusId = "PCI:1@0:0:0";'
  reject $H/default.nix '    hardware.nvidia = {'
  expect $H/default.nix 'keyboardLayout = "de";'
  expect $H/default.nix 'system.stateVersion = "25.11";'
  expect $H/default.nix "repoPath = \"$R\";"
  expect $H/boot.nix 'ryoku.host.bootReviewed = false;'
  expect $H/boot.nix 'boot.loader.systemd-boot.enable = true;'
  for f in $H/*.nix; do nix-instantiate --parse "$f" > /dev/null || fail "$f does not parse"; done

  # Existing host: refused without --force, kept aside with it.
  if run $A $TMPDIR/lspci-a --profile full --user alice --yes > $TMPDIR/a5.out 2>&1; then
    fail "overwrote an existing host"
  fi
  expect $TMPDIR/a5.out "already exists"
  run $A $TMPDIR/lspci-a --profile minimal --user alice --yes --force > $TMPDIR/a4.out 2>&1 || { cat $TMPDIR/a4.out; fail "--force run failed"; }
  expect $H/default.nix 'profile = "minimal";'
  expect $H/default.nix 'nixpkgs.config.allowUnfree = false;'
  ls -d $R/hosts/.laptop-a.replaced-* > /dev/null || fail "replaced host not kept"

  # ── Fixture B: AMD desktop, BIOS GRUB, no battery/Wi-Fi, no stateVersion ─
  B=$TMPDIR/desktop
  mkdir -p $B/etc/nixos $B/proc $B/sys/class/dmi/id $B/sys/class/net/enp5s0 $B/boot/grub
  touch $B/etc/NIXOS
  echo "tower" > $B/etc/hostname
  : > $B/etc/passwd
  printf 'vendor_id\t: AuthenticAMD\n' > $B/proc/cpuinfo
  echo 3 > $B/sys/class/dmi/id/chassis_type
  echo '{ ... }: { }' > $B/etc/nixos/hardware-configuration.nix
  echo '{ ... }: { boot.loader.grub.enable = true; }' > $B/etc/nixos/configuration.nix
  echo '0000:0a:00.0 VGA compatible controller [0300]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 23 [1002:73ff] (rev c1)' > $TMPDIR/lspci-b

  if run $B $TMPDIR/lspci-b --profile minimal --user bob --dry-run > $TMPDIR/b0.out 2>&1; then
    fail "guessed a missing stateVersion"
  fi
  expect $TMPDIR/b0.out "never guess it"
  run $B $TMPDIR/lspci-b --profile minimal --user bob --state-version 24.11 --yes > $TMPDIR/b.out 2>&1
  expect $TMPDIR/b.out "user bob does not exist yet"
  expect $TMPDIR/b.out "hybrid graphics    no"
  expect $TMPDIR/b.out "desktop (chassis type 3), battery: no"
  expect $TMPDIR/b.out "BIOS / grub"
  HB=$R/hosts/tower
  expect $HB/default.nix 'hardware.intelVideoAcceleration = false;'
  reject $HB/default.nix 'hardware.nvidia'
  expect $HB/boot.nix 'boot.loader.grub.device = throw'
  for f in $HB/*.nix; do nix-instantiate --parse "$f" > /dev/null || fail "$f does not parse"; done

  # ── Refusals ────────────────────────────────────────────────────────────
  C=$TMPDIR/not-nixos; mkdir -p $C/etc
  if run $C $TMPDIR/lspci-b --profile minimal --user bob --dry-run > $TMPDIR/c.out 2>&1; then fail "ran on non-NixOS"; fi
  expect $TMPDIR/c.out "this is not a NixOS system"
  if RYOKU_SYSROOT=$A RYOKU_ARCH=aarch64 "$bs" --repo $R --profile full --user alice --dry-run > $TMPDIR/d.out 2>&1; then fail "accepted aarch64"; fi
  if run $A $TMPDIR/lspci-a --user alice --dry-run > $TMPDIR/e.out 2>&1; then fail "ran without --profile"; fi
  if run $A $TMPDIR/lspci-a --profile full --user root --dry-run > $TMPDIR/f.out 2>&1; then fail "accepted root"; fi

  echo "ryoku-bootstrap: all checks passed" | tee $out
''
