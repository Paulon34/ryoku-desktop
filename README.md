<div align="center">

# RYOKU DESKTOP

**A reproducible NixOS desktop. Your hardware. Your settings. Your way.**

Hyprland · DankMaterialShell · Quickshell · Material You · NixOS

[🇬🇧 English](./README.md) · [🇧🇷 Português](./README.pt-BR.md)

![NixOS](https://img.shields.io/badge/NixOS-x86__64-101922?style=flat-square&logo=nixos&logoColor=00c8f7)
![Hyprland](https://img.shields.io/badge/Hyprland-Wayland-101922?style=flat-square&logo=linux&logoColor=00c8f7)
![License](https://img.shields.io/badge/Code-MIT-101922?style=flat-square)
![Status](https://img.shields.io/badge/Status-Early%20release-101922?style=flat-square)

</div>

---

## `> what is ryoku?`

**Ryoku Desktop** is an opinionated, configurable desktop experience built *on top of NixOS*. It combines a patched [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) (DMS) on Quickshell, Hyprland, wallpaper-driven Material You colors and its own **Ryoku Settings** application.

Ryoku is **not** a new Linux distribution, a replacement for the NixOS installer or a generic dotfile bundle. It is a reproducible NixOS module stack with a hardware-aware, review-first bootstrap.

**Two shell styles, one system:**

| **Quattro** (default) | **Islands** |
|---|---|
| Compact, edge-to-edge flat bar; numbered workspaces; framed panels and restrained motion, inspired by Omarchy Quattro. | The original Ryoku layout with floating islands and a softer Material You appearance. |

Both styles retain the same Ryoku functionality. Appearance settings and color palettes are shared.

> **Screenshots** of Quattro, Islands and Ryoku Settings will be added in a future update.

## `> features --list`

- **Ryoku Settings:** a Qt 6/QML + C++ settings application with PT-BR/English, keyboard search, display/network/audio/power pages, Git and Nix integration, and a Polkit-authorized Apply helper.
- **Dynamic Material You:** wallpaper-based palettes using Matugen, with coherent colors across the shell, terminal and Hyprland.
- **Shell profiles:** *Economy*, *Balanced* and *Cinematic*, with event-driven automatic adaptation to battery and power profiles. No recurring polling service added for this feature.
- **Wallpapers:** static images and optional video wallpaper using mpvpaper, poster frames for Material You and the lock screen, and selectable performance levels. **No videos are bundled** in the public edition.
- **Desktop experience:** DMS bar, launcher, Control Center, DankDash, notification grouping, Do Not Disturb, OSD, tray, lock screen and an adaptive SDDM login theme.
- **Declarative system:** NixOS + Home Manager, selected Flatpak apps via a JSON configuration, a fixed-host Apply helper and rollback through NixOS generations.
- **Machine profiles:** Minimal / Full, plus independently selectable features such as development, gaming, virtualization and printing.

### Minimal vs Full

| | **Minimal** | **Full** |
|---|:---:|:---:|
| Ryoku desktop, Quattro/Islands, Settings, Material You, SDDM | ✅ | ✅ |
| Static wallpaper / optional video engine | ✅ | ✅ |
| Flatpak integration (no apps declared by default) | ✅ | ✅ |
| Extra desktop apps and development tools | — | ✅ |
| Gaming, multimedia, virtualization, network tools, printing | — | ✅ |
| Unfree packages needed by optional apps | — | ✅ |
| Security testing tools, phone tools, Tailscale, SSH server | Opt-in | Opt-in |

Measured build closures in the development environment were approximately **8.6 GiB (Minimal)** and **27.4 GiB (Full)**. These are *Nix store closure sizes*, not download estimates or minimum free-disk requirements.

## `> compatibility`

**Requirements:** an **already installed NixOS** system, **x86_64-linux**, Git, Internet access for initial builds, and the ability to review the generated NixOS boot configuration. Ryoku's bootstrap **does not install NixOS or partition disks**.

| Platform | Verification |
|---|---|
| Intel i5-11300H laptop, Intel Iris Xe + NVIDIA GTX 1650 (PRIME) | Real development machine in daily use |
| QEMU/KVM with virtio-gpu / software rendering | Minimal booted through SDDM → Hyprland → DMS on first login |
| Intel + NVIDIA hybrid laptop; AMD Navi 23 desktop | Hardware-detection fixtures only |
| AMD physical GPUs, other NVIDIA setups, HiDPI, LUKS, Secure Boot, BIOS hardware | **Not yet validated on physical hardware** |
| aarch64 / non-NixOS hosts | Not supported by bootstrap |

The bootstrap detects CPUs, GPUs, form factor, battery, network hardware, connected displays and boot environment. **It does not automatically enable NVIDIA drivers**, guess disk identifiers or approve bootloader changes.

Ryoku currently pins the DMS patch stack to **DMS 1.5.3**, with a tested NixOS/nixpkgs snapshot. Blindly updating `flake.lock` can break the patches. Upgrade this dependency only after testing a compatibility migration.

## `> install --review-first`

> **Before starting:** back up `/etc/nixos`, your files and boot configuration. Know how to choose an older NixOS generation at the boot menu. Installing this desktop changes your NixOS system configuration. Review generated files before building, and avoid applying it remotely without physical recovery access.

**1. Clone the repository.**

```bash
git clone https://github.com/Paulon34/ryoku-desktop ~/ryoku
cd ~/ryoku
```

**2. Preview detection — writes nothing.**

```bash
nix --extra-experimental-features 'nix-command flakes' run .#bootstrap -- \
  --profile minimal --dry-run
```

**3. Generate your host.** Change `minimal` to `full` if you want the extra application sets.

```bash
nix --extra-experimental-features 'nix-command flakes' run .#bootstrap -- \
  --profile minimal
```

This writes `hosts/<host>/default.nix`, `home.nix` and `boot.nix`, plus a **copy** of your existing `/etc/nixos/hardware-configuration.nix`. It does not rebuild, edit `/etc/nixos` or enable the NVIDIA driver.

**4. Review the machine configuration.**

- Compare `hosts/<host>/boot.nix` with your working `/etc/nixos/configuration.nix`, including bootloader and EFI/BIOS settings. Only after reviewing, set `ryoku.host.bootReviewed = true;`.
- Check the generated username, keyboard layout, monitors, features, hardware settings and `system.stateVersion` in `hosts/<host>/default.nix`.
- If you use NVIDIA, enable and configure its driver manually after reviewing the generated comments and the correct PCI bus IDs.
- If the desktop user does not already exist, **plan for first-login password setup**: the account is created at system activation, not at build time. Use a local console/admin account and set `sudo passwd <user>` immediately after activation and *before* signing out/rebooting into a login you cannot use.

**5. Stage host files and build.** The Nix flake only sees Git-tracked files.

For the examples below, **replace `workstation` with the host name generated by the bootstrap**:

```bash
git add hosts/workstation
nix --extra-experimental-features 'nix-command flakes' build \
  .#nixosConfigurations.workstation.config.system.build.toplevel
```

**6. Activate with a recovery plan.** A safer first step is to set the next boot generation, then reboot with physical access; or use `nixos-rebuild test` to inspect the live session before committing the configuration.

```bash
sudo env NIX_CONFIG='experimental-features = nix-command flakes' \
  nixos-rebuild boot --flake .#workstation
```

After the first successful boot, check your display session, user password, networking, permissions and DMS. If you need to apply immediately instead, `nixos-rebuild switch` will activate services and may interrupt your current graphical session.

The first-session hooks initialize the DMS settings and apply the default Quattro bar and wallpaper. There may be a short delay on first login.

### Basic checks

```bash
dms ipc call ryoku status
systemctl --user status dms.service
systemctl --user status ryoku-video-wallpaper.service
```

`ryoku-video-wallpaper.service` can legitimately be inactive when no video wallpaper has been selected.

## `> configure`

Open **Ryoku Settings** to change appearance, wallpaper, display settings and other supported preferences.

- **Live changes:** static/video wallpaper and visual effect profiles can apply during the current session.
- **Changes requiring Apply:** shell style (Quattro/Islands), declared Flatpak apps, login wallpaper and weather location are projected into the NixOS/Home Manager configuration. Apply uses Polkit and a fixed, build-time host/repository path.
- **Configuration source:** `ryoku/settings.json` (schema version 1). The public default intentionally includes **no city, video or declared Flatpak apps**.
- **Video wallpaper:** add your own licensed `.mp4`, `.webm`, `.mkv` or `.mov` to `assets/wallpapers/`, `git add` it (Git LFS is recommended for large files) and rebuild with `sudo nixos-rebuild switch --flake .#<host>` so Home Manager installs it into `~/.local/share/wallpapers`; then select it in Settings. Playback and hardware-decoding support depend on your GPU/driver stack.

`nix flake check` alone does not run all test builds. For additional validation:

```bash
nix --extra-experimental-features 'nix-command flakes' flake check
nix --extra-experimental-features 'nix-command flakes' build .#checks.x86_64-linux.bootstrap
nix --extra-experimental-features 'nix-command flakes' build \
  .#nixosConfigurations.ryoku-minimal.config.system.build.toplevel
nix --extra-experimental-features 'nix-command flakes' build \
  .#nixosConfigurations.ryoku-full.config.system.build.toplevel
```

The QEMU first-login test is separately exposed as `.#legacyPackages.x86_64-linux.vmTest` and needs KVM. The **Full** profile has been built, but the graphical first-login VM test covered **Minimal only**.

## `> update / rollback`

Review changes before updating: keep a backup of locally generated `hosts/<host>/` and `ryoku/settings.json`, then pull tested Ryoku releases. **Do not indiscriminately run `nix flake update`** while DMS remains patch-pinned to 1.5.3.

For a system rollback, select a previous NixOS generation at boot, or, when the machine is running:

```bash
sudo nixos-rebuild switch --rollback
```

Ryoku Settings also exposes generation management in its Nix/Updates page.

## `> source / credits`

Ryoku's original code is offered under **MIT**. Components derived from other projects retain their own licenses — notably the **GPL-3.0-or-later** SDDM astronaut overlay and the **Apache-2.0** Material Symbols subset. The public procedural wallpapers are **CC0-1.0**. See [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md), [LICENSE](./LICENSE) and [LICENSES/](./LICENSES/).

The Quattro style draws inspiration from [Omarchy Quattro](https://github.com/omacom/omarchy); interaction research also considered [43PR/dotfiles](https://github.com/43PR/dotfiles). The desktop builds on NixOS, Home Manager, Hyprland, Quickshell, DMS, Matugen and mpvpaper. **Ryoku is not affiliated with or endorsed by those projects.**

**Contributions:** bug reports should include hardware, NixOS release, Ryoku commit, reproduction steps and redacted logs. Never paste secrets, serial numbers, machine-specific UUIDs or personal network configuration into issues.

<div align="center">

Built for customization, reproducibility and open source.

**[Português](./README.pt-BR.md)** · **[Third-party credits](./THIRD_PARTY_NOTICES.md)**

</div>