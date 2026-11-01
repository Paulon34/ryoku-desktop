{ pkgs, self, inputs }:

let
  # appearance.wallpaper of the checkout under test (empty when unset).
  w = (import ../ryoku/lib.nix { inherit (pkgs) lib; }).wallpaper;
  wallpaper = if w == null then "" else w;
in

# Boots the minimal profile in QEMU, logs the Ryoku user into Hyprland and
# checks the session stack: SDDM, Home Manager, Hyprland, the DMS shell with
# the Quattro style, Ryoku Settings and the privileged Apply helper.
#   nix build .#legacyPackages.x86_64-linux.vmTest     (needs KVM)
# Rendering is software (llvmpipe), so this checks wiring, not performance.

pkgs.testers.runNixOSTest {
  name = "ryoku-minimal";

  node.specialArgs = { inherit inputs; };

  nodes.machine = { lib, pkgs, ... }: {
    imports = [
      self.nixosModules.ryoku
      inputs.home-manager.nixosModules.home-manager
      inputs.nix-flatpak.nixosModules.nix-flatpak
    ];

    networking.hostName = "ryoku-vm";
    system.stateVersion = "26.05";

    ryoku = {
      profile = "minimal";
      user.name = "ryoku";
      # Offline VM: no Flathub downloads.
      features.flatpak = false;
      settingsApply.repoPath = "/etc/ryoku-test-repo";
    };

    users.users.ryoku.password = "ryoku";
    environment.systemPackages = [ pkgs.jq ];

    services.displayManager.autoLogin = {
      enable = true;
      user = "ryoku";
    };
    services.displayManager.defaultSession = "hyprland";

    # Software rendering in QEMU.
    environment.sessionVariables = {
      WLR_RENDERER_ALLOW_SOFTWARE = "1";
      WLR_NO_HARDWARE_CURSORS = "1";
    };

    virtualisation = {
      memorySize = 6144;
      cores = 4;
      resolution = { x = 1920; y = 1080; };
      qemu.options = [ "-vga none" "-device virtio-gpu-pci,xres=1920,yres=1080" ];
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("display-manager.service")

    with subtest("Ryoku system pieces"):
        machine.succeed("id ryoku")
        machine.succeed("test -x /run/current-system/sw/bin/ryoku-settings")
        helper = machine.succeed("cat /etc/ryoku/settings-apply-helper").strip()
        machine.succeed(f"test -x {helper}")
        machine.succeed("test -s /etc/ryoku/applied-settings-hash")
        dms = machine.succeed("readlink -f /run/current-system/sw/bin/dms").strip()
        machine.succeed(f"grep -q 'shellStyle: \"quattro\"' {dms.rsplit('/bin/', 1)[0]}/share/quickshell/dms/Common/RyokuVisual.qml")
        # minimal must not pull optional feature sets
        machine.fail("test -e /run/current-system/sw/bin/steam")
        machine.fail("test -e /run/current-system/sw/bin/code")
        machine.fail("systemctl cat docker.service")

    with subtest("Home Manager for the Ryoku user"):
        machine.wait_for_unit("home-manager-ryoku.service")
        machine.succeed("grep -q 'no_anim on, match:namespace' /home/ryoku/.config/hypr/hyprland.conf")
        machine.succeed("grep -q 'kb_layout=us' /home/ryoku/.config/hypr/hyprland.conf")
        machine.succeed("grep -q /home/ryoku/.config/matugen/templates /home/ryoku/.config/matugen/config.toml")

    with subtest("Hyprland session with the DMS shell"):
        machine.wait_until_succeeds("pgrep -u ryoku -x Hyprland || pgrep -u ryoku -f 'bin/Hyprland'", timeout=180)
        machine.wait_until_succeeds("pgrep -u ryoku -f 'quickshell -p'", timeout=180)
        # First run: DMS writes its settings, then the Ryoku layer is applied.
        machine.wait_until_succeeds("test -f /home/ryoku/.config/DankMaterialShell/settings.json", timeout=120)
        machine.wait_until_succeeds(
            "jq -e '.barConfigs[] | select(.id == \"default\") | .spacing == 0 and .noBackground == false"
            " and (.leftWidgets | index(\"workspaceSwitcher\"))' /home/ryoku/.config/DankMaterialShell/settings.json",
            timeout=120)
        if "${wallpaper}":
            machine.wait_until_succeeds(
                "jq -e '.wallpaperPath | endswith(\"/.local/share/wallpapers/${wallpaper}\")'"
                " /home/ryoku/.local/state/DankMaterialShell/session.json",
                timeout=120)
        journal = "su - ryoku -c 'XDG_RUNTIME_DIR=/run/user/$(id -u ryoku) journalctl --user -b -u ryoku-dms-bar -u ryoku-dms-session --no-pager'"
        machine.wait_until_succeeds(f"{journal} | grep -q 'running shell reloaded settings.json'", timeout=120)
        if "${wallpaper}":
            machine.wait_until_succeeds(f"{journal} | grep -q 'first wallpaper set'", timeout=120)
        machine.sleep(15)
        machine.screenshot("ryoku-minimal-desktop")
        machine.succeed("su - ryoku -c 'XDG_RUNTIME_DIR=/run/user/$(id -u ryoku) dms ipc call ryoku status' | grep -q '\"shellStyle\":\"quattro\"'")
  '';
}
