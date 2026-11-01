{ config, lib, pkgs, ... }:

let
  # System generations kept on disk and listed in the boot menu.
  keepGenerations = 3;

  bootMount =
    if config.boot.loader.systemd-boot.xbootldrMountPoint != null
    then config.boot.loader.systemd-boot.xbootldrMountPoint
    else config.boot.loader.efi.efiSysMountPoint;

  # Rejects any bootspec field this entry cannot reproduce exactly like the
  # systemd-boot builder does; prints the first problem, or nothing.
  bootspecCheck = ''
    def extra(obj; allowed): ((obj // {}) | keys) - allowed;
    def line: type == "string" and (test("[\n\r]") | not);
    . as $b
    | $b["org.nixos.bootspec.v1"] as $v
    | [
        (extra($b; ["org.nixos.bootspec.v1", "org.nixos.specialisation.v1",
                    "org.nixos.systemd-boot", "org.nixos.nixos-init.v1",
                    "org.nixos.extra-initrd.v1"])[]
          | "unsupported bootspec extension \(.)"),
        (if ($v | type) != "object" then "missing org.nixos.bootspec.v1" else
          (extra($v; ["init", "initrd", "kernel", "kernelParams", "label",
                      "system", "toplevel"])[]
            | if . == "initrdSecrets" then "initrd secrets"
              else "unexpected field org.nixos.bootspec.v1.\(.)" end),
          (if ([$v.init, $v.initrd, $v.kernel, $v.label, $v.toplevel]
               | all(line)) | not
           then "init/initrd/kernel/label/toplevel missing or not single-line" else empty end),
          (if ($v.kernelParams | type) != "array"
              or ($v.kernelParams | all(line) | not)
           then "kernelParams is not a list of single-line strings" else empty end),
          (if $v.toplevel != $top
           then "bootspec toplevel differs from the booted system" else empty end)
        end),
        (if (($b["org.nixos.extra-initrd.v1"].paths // []) | length) > 0
         then "additional initrds (org.nixos.extra-initrd.v1)" else empty end),
        (extra($b["org.nixos.extra-initrd.v1"]; ["paths"])[]
          | "unexpected field org.nixos.extra-initrd.v1.\(.)"),
        (extra($b["org.nixos.systemd-boot"]; ["sortKey"])[]
          | if . == "devicetree" then "devicetree"
            else "unexpected field org.nixos.systemd-boot.\(.)" end)
      ]
    | .[0] // empty
  '';

  # Keeps the booted system bootable while it is older than the newest
  # generations the systemd-boot builder lists; lives outside EFI/nixos and
  # nixos-*.conf so the builder's garbage collection never touches it.
  bootedEntry = pkgs.writeShellApplication {
    name = "ryoku-booted-entry";
    runtimeInputs = [ pkgs.coreutils pkgs.diffutils pkgs.gnused pkgs.jq ];
    text = ''
      mode=''${1:-}
      dry_run=0
      if [ "''${2:-}" = "--dry-run" ]; then dry_run=1; fi
      case "$mode" in
        sync|cleanup) ;;
        *) echo "usage: ryoku-booted-entry sync|cleanup [--dry-run]" >&2; exit 2 ;;
      esac

      boot=''${RYOKU_BOOTED_BOOT_DIR:-${bootMount}}
      profile=''${RYOKU_BOOTED_PROFILE:-/nix/var/nix/profiles/system}
      run_dir=''${RYOKU_BOOTED_RUN_DIR:-/run}
      machine_id_file=''${RYOKU_BOOTED_MACHINE_ID:-/etc/machine-id}
      margin=''${RYOKU_BOOTED_SPACE_MARGIN:-$((32 * 1024 * 1024))}
      keep_count=${toString keepGenerations}

      entry=$boot/loader/entries/ryoku-booted.conf
      entry_tmp=$boot/loader/entries/.ryoku-booted.conf.tmp
      efi_dir=$boot/EFI/ryoku-booted
      efi_tmp=$boot/EFI/.ryoku-booted.tmp

      note() { echo "ryoku-booted-entry: $*"; }
      warn() { echo "ryoku-booted-entry: warning: $*" >&2; }

      # EFI/ryoku-booted never outlives its entry; staging files never persist.
      tidy() {
        rm -rf "$efi_tmp" "$entry_tmp"
        if [ ! -e "$entry" ]; then rm -rf "$efi_dir"; fi
      }

      remove_entry() {
        if [ ! -e "$entry" ] && [ ! -e "$efi_dir" ]; then return 0; fi
        if [ "$dry_run" -eq 1 ]; then
          note "would remove ryoku-booted entry: $1"
          return 0
        fi
        rm -f "$entry"
        rm -rf "$efi_dir"
        sync -f "$boot"
        note "removed ryoku-booted entry: $1"
      }

      refuse() {
        warn "$1; NOT creating a boot entry for the booted system (old rollback is not protected)"
        remove_entry "does not match a protectable booted system"
        exit 0
      }

      if [ "$dry_run" -eq 0 ]; then
        tidy
        trap tidy EXIT
      fi

      declare -A target=()
      unsorted=()
      for link in "$profile"-*-link; do
        [ -L "$link" ] || continue
        n=''${link#"$profile"-}
        n=''${n%-link}
        [[ $n =~ ^[0-9]+$ ]] || continue
        t=$(readlink -e "$link") || continue
        unsorted+=("$n")
        target[$n]=$t
      done
      gens=()
      if [ "''${#unsorted[@]}" -gt 0 ]; then
        mapfile -t gens < <(printf '%s\n' "''${unsorted[@]}" | sort -n)
      fi
      start=$(( ''${#gens[@]} > keep_count ? ''${#gens[@]} - keep_count : 0 ))
      latest=("''${gens[@]:start}")

      booted=$(readlink -e "$run_dir/booted-system" || true)
      booted_gen=""
      in_latest=0
      if [ -n "$booted" ]; then
        for n in "''${gens[@]}"; do
          if [ "''${target[$n]}" = "$booted" ]; then booted_gen=$n; fi
        done
        for n in "''${latest[@]}"; do
          if [ "''${target[$n]}" = "$booted" ]; then in_latest=1; fi
        done
      fi

      if [ "$mode" = cleanup ]; then
        [ -e "$entry" ] || exit 0
        if [ -z "$booted" ]; then
          remove_entry "booted system unknown"
        elif [ "$in_latest" -eq 1 ]; then
          remove_entry "booted generation is among the newest $keep_count"
        else
          booted_init=$(jq -r '."org.nixos.bootspec.v1".init // empty' "$booted/boot.json" 2>/dev/null || true)
          entry_init=$(sed -n 's/^options init=\([^ ]*\).*/\1/p' "$entry")
          if [ -z "$booted_init" ] || [ "$entry_init" != "$booted_init" ]; then
            remove_entry "entry does not match the booted system"
          elif [ ! -f "$efi_dir/kernel.efi" ] || [ ! -f "$efi_dir/initrd.efi" ]; then
            remove_entry "entry is incomplete"
          else
            note "keeping ryoku-booted entry: still booted into generation ''${booted_gen:-?}, older than the newest $keep_count"
          fi
        fi
        exit 0
      fi

      if [ -z "$booted" ]; then
        refuse "cannot resolve $run_dir/booted-system"
      fi
      if [ "$in_latest" -eq 1 ]; then
        remove_entry "booted generation is among the newest $keep_count"
        exit 0
      fi
      if [ -z "$booted_gen" ]; then
        for n in "''${gens[@]}"; do
          for s in "''${target[$n]}"/specialisation/*; do
            if [ "$(readlink -e "$s" || true)" = "$booted" ]; then
              refuse "booted system is specialisation ''${s##*/} of generation $n"
            fi
          done
        done
        refuse "booted system $booted is not a generation of $profile"
      fi

      bootspec=$booted/boot.json
      if [ ! -f "$bootspec" ]; then refuse "$bootspec not found"; fi
      problem=$(jq -r --arg top "$booted" ${lib.escapeShellArg bootspecCheck} "$bootspec") \
        || refuse "cannot parse $bootspec"
      if [ -n "$problem" ]; then refuse "unsupported bootspec: $problem"; fi

      field() { jq -r --arg k "$1" '."org.nixos.bootspec.v1"[$k]' "$bootspec"; }
      init=$(field init)
      kernel=$(field kernel)
      initrd=$(field initrd)
      label=$(field label)
      params=$(jq -r '."org.nixos.bootspec.v1".kernelParams | join(" ")' "$bootspec")
      for f in "$kernel" "$initrd"; do
        if [ ! -f "$f" ]; then refuse "$f is missing"; fi
      done

      built=$(date -d "@$(stat -L -c %Z "$profile-$booted_gen-link")" +%F)
      machine_id=""
      if [ -r "$machine_id_file" ]; then machine_id=$(head -n1 "$machine_id_file"); fi
      desired=$(
        echo "title NixOS (booted rollback)"
        echo "version Generation $booted_gen $label, built on $built"
        echo "linux /EFI/ryoku-booted/kernel.efi"
        echo "initrd /EFI/ryoku-booted/initrd.efi"
        echo "options init=$init''${params:+ $params}"
        if [ -n "$machine_id" ]; then echo "machine-id $machine_id"; fi
        echo "sort-key ryoku-booted"
      )

      if [ -f "$entry" ] && [ "$(cat "$entry")" = "$desired" ] \
        && cmp -s "$kernel" "$efi_dir/kernel.efi" \
        && cmp -s "$initrd" "$efi_dir/initrd.efi"; then
        note "ryoku-booted entry already up to date for generation $booted_gen"
        exit 0
      fi

      remove_entry "replaced by generation $booted_gen"
      need=$(( $(stat -L -c %s "$kernel") + $(stat -L -c %s "$initrd") + margin ))
      avail=$(df -B1 --output=avail "$boot" | tail -n1 | tr -d ' ')
      if [ "$avail" -lt "$need" ]; then
        warn "not enough space on $boot (need $need bytes incl. margin, have $avail); NOT creating a boot entry for booted generation $booted_gen (old rollback is not protected)"
        exit 0
      fi
      if [ "$dry_run" -eq 1 ]; then
        note "would create ryoku-booted entry for generation $booted_gen"
        exit 0
      fi

      mkdir -p "$boot/EFI" "$boot/loader/entries"
      mkdir "$efi_tmp"
      cp "$kernel" "$efi_tmp/kernel.efi"
      cp "$initrd" "$efi_tmp/initrd.efi"
      printf '%s\n' "$desired" > "$entry_tmp"
      sync -f "$boot"
      mv "$efi_tmp" "$efi_dir"
      mv "$entry_tmp" "$entry"
      sync -f "$boot"
      note "created ryoku-booted entry for generation $booted_gen (booted rollback older than the newest $keep_count)"
    '';
  };

  pruneSystemGenerations = pkgs.writeShellApplication {
    name = "ryoku-prune-system-generations";
    runtimeInputs = [ config.nix.package pkgs.coreutils bootedEntry ];
    text = ''
      profile=/nix/var/nix/profiles/system
      keep_count=${toString keepGenerations}
      dry_run=0
      case "''${1:-}" in
        --dry-run) dry_run=1 ;;
        "") ;;
        *) echo "usage: ryoku-prune-system-generations [--dry-run]" >&2; exit 2 ;;
      esac

      # Before any generation (and thus the GC that follows) can drop the
      # system the extra rollback entry points to.
      if [ "$dry_run" -eq 1 ]; then
        ryoku-booted-entry cleanup --dry-run
      else
        ryoku-booted-entry cleanup
      fi

      declare -A target=()
      unsorted=()
      for link in "$profile"-*-link; do
        [ -L "$link" ] || continue
        n=''${link#"$profile"-}
        n=''${n%-link}
        [[ $n =~ ^[0-9]+$ ]] || continue
        unsorted+=("$n")
        target[$n]=$(readlink -f "$link")
      done
      if [ "''${#unsorted[@]}" -eq 0 ]; then
        echo "no system generations found"
        exit 0
      fi
      mapfile -t gens < <(printf '%s\n' "''${unsorted[@]}" | sort -n)

      current=$(readlink "$profile")
      current=''${current#system-}
      current=''${current%-link}
      if [ -z "''${target[$current]:-}" ]; then
        echo "cannot resolve the current system generation; nothing removed" >&2
        exit 1
      fi

      declare -A keep=()
      add_reason() { keep[$1]="''${keep[$1]:+''${keep[$1]}, }$2"; }

      start=$(( ''${#gens[@]} > keep_count ? ''${#gens[@]} - keep_count : 0 ))
      for n in "''${gens[@]:start}"; do add_reason "$n" "newest $keep_count"; done
      add_reason "$current" "profile current"
      for run in /run/current-system /run/booted-system; do
        live=$(readlink -f "$run") || continue
        for n in "''${gens[@]}"; do
          if [ "''${target[$n]}" = "$live" ]; then add_reason "$n" "''${run#/run/}"; fi
        done
      done

      drop=()
      for n in "''${gens[@]}"; do
        if [ -n "''${keep[$n]:-}" ]; then
          echo "keep    $n  (''${keep[$n]})"
        else
          drop+=("$n")
        fi
      done
      echo "remove  ''${drop[*]:-none}"
      [ "''${#drop[@]}" -gt 0 ] || exit 0

      if [ "$dry_run" -eq 1 ]; then
        if [ "$EUID" -eq 0 ]; then
          nix-env -p "$profile" --dry-run --delete-generations "''${drop[@]}"
        fi
        echo "dry run: nothing removed"
        exit 0
      fi
      nix-env -p "$profile" --delete-generations "''${drop[@]}"
    '';
  };
in
{
  environment.systemPackages = [ pruneSystemGenerations ];

  boot.loader.systemd-boot.configurationLimit = keepGenerations;

  boot.loader.systemd-boot.extraInstallCommands = ''
    ${lib.getExe bootedEntry} sync \
      || echo "ryoku-booted-entry: warning: failed; an old booted rollback may not be bootable from the menu" >&2
  '';

  systemd.services.ryoku-prune-system-generations = {
    description = "Keep the newest ${toString keepGenerations} NixOS system generations";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe pruneSystemGenerations;
    };
  };

  # Retention is by count (prune service above), so no age-based
  # --delete-older-than here: the GC only collects unreferenced paths.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    persistent = true;
    randomizedDelaySec = "45min";
  };

  systemd.services.nix-gc = {
    wants = [ "ryoku-prune-system-generations.service" ];
    after = [ "ryoku-prune-system-generations.service" ];
  };

  nix.settings.auto-optimise-store = true;

  nix.optimise = {
    automatic = true;
    dates = [ "monthly" ];
  };
}
