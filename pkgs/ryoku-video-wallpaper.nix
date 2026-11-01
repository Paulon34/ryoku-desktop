{
  lib,
  writeShellApplication,
  coreutils,
  gawk,
  jq,
  ffmpeg,
  mpvpaper,
  systemd,
}:

# Runtime side of Ryoku video wallpapers. One CLI shared by Ryoku Settings,
# the ryoku-video-wallpaper user unit (home/video-wallpaper.nix) and
# scripts/change-wallpaper.sh, so ordering/fallback logic lives in one place.
#
# Model (mirrors static wallpapers, which are live via DMS IPC):
#   - DMS keeps rendering/owning the *static* wallpaper. For a video, DMS is
#     given a poster frame: Matugen derives the palette from it once and the
#     DMS lock screen shows it.
#   - mpvpaper renders the video on the background layer. While it runs, the
#     DMS wallpaper layer is hidden (screenPreferences.wallpaper = []), so only
#     one renderer draws the desktop background.
#   - The current selection is runtime state in
#     $XDG_STATE_HOME/ryoku/video-wallpaper.env (like DMS session.json for
#     images); ryoku/settings.json records the saved choice.
#
# mpv options are validated against mpv 0.41 / mpvpaper 1.9:
#   - hwdec=vaapi: Intel iGPU zero-copy. auto-safe picks nvdec-copy here,
#     which wakes the PRIME-offload dGPU; vaapi falls back to software instead.
#   - gpu-hwdec-interop=vaapi: otherwise the drmprime/cuda interops also
#     probe and keep the NVIDIA render node open.
#   - vf=fps=N keeps VA-API frames on the GPU (hwdec-current stays "vaapi").
#   - panscan=1.0 crops to fill, matching the DMS "Fill" wallpaper mode.
writeShellApplication {
  name = "ryoku-video-wallpaper";

  runtimeInputs = [
    coreutils
    gawk
    jq
    ffmpeg
    mpvpaper
    systemd
  ];

  text = ''
    unit=ryoku-video-wallpaper.service
    state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/ryoku"
    env_file="$state_dir/video-wallpaper.env"
    screens_backup="$state_dir/dms-wallpaper-screens.json"
    poster_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/ryoku/video-posters"
    dms_settings="''${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell/settings.json"

    log() { printf 'ryoku-video-wallpaper: %s\n' "$*" >&2; }
    die() { log "$*"; exit 1; }

    usage() {
      cat >&2 <<'EOF'
    Usage:
      ryoku-video-wallpaper apply <video> [--loop 0|1] [--audio 0|1]
                                  [--profile economy|balanced|quality]
                                  [--pause-covered 0|1]
      ryoku-video-wallpaper stop
      ryoku-video-wallpaper poster <video>
      ryoku-video-wallpaper status
    Unit internals: check | run | dms-hide | dms-restore
    EOF
      exit 2
    }

    is_video() {
      case "''${1,,}" in
        *.mp4 | *.webm | *.mkv | *.mov) return 0 ;;
        *) return 1 ;;
      esac
    }

    # Absolute path made of characters that are safe in a systemd
    # EnvironmentFile and in the mpvpaper argv (gallery ids already are).
    is_safe_path() {
      [[ "$1" == /* && "$1" =~ ^[A-Za-z0-9._/+-]+$ && "$1" != *..* ]]
    }

    is_bool() { [[ "$1" == 0 || "$1" == 1 ]]; }

    # Deterministic cache key: identity of the resolved file. Gallery entries
    # are Nix store symlinks, so a changed video always gets a new poster.
    poster_path() {
      local real size mtime key stem
      real=$(readlink -f -- "$1")
      size=$(stat -c %s -- "$real")
      mtime=$(stat -c %Y -- "$real")
      key=$(printf '%s\0%s\0%s' "$real" "$size" "$mtime" | sha256sum | cut -c1-16)
      stem=$(basename -- "$1")
      printf '%s/%s-%s.jpg\n' "$poster_dir" "''${stem%.*}" "$key"
    }

    # One-shot ffmpeg: best of 24 frames starting at min(2s, 15% of the
    # duration), which skips black fade-in frames. Never runs continuously.
    cmd_poster() {
      local video=$1 out dur ss tmp
      [[ -r "$video" ]] || die "video not found: $video"
      out=$(poster_path "$video")
      if [[ ! -s "$out" ]]; then
        mkdir -p "$poster_dir"
        dur=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 -- "$video" || true)
        ss=$(awk -v d="''${dur:-0}" 'BEGIN { t = d * 0.15; if (t > 2) t = 2; if (!(t > 0)) t = 0; printf "%.3f", t }')
        tmp="$out.$$.tmp.jpg"
        if ! ffmpeg -nostdin -v error -y -ss "$ss" -i "$video" -map 0:v:0 \
          -vf 'thumbnail=n=24,scale=min(iw\,2560):-2' -frames:v 1 -q:v 3 "$tmp" \
          || [[ ! -s "$tmp" ]]; then
          ffmpeg -nostdin -v error -y -i "$video" -map 0:v:0 \
            -vf 'scale=min(iw\,2560):-2' -frames:v 1 -q:v 3 "$tmp" \
            || { rm -f "$tmp"; die "could not extract a poster frame from $video"; }
        fi
        mv -f "$tmp" "$out"
      fi
      printf '%s\n' "$out"
    }

    dms_wallpaper_screens() {
      jq -c '.screenPreferences.wallpaper // ["all"]' "$dms_settings"
    }

    dms_set_wallpaper_screens() {
      local tmp="$dms_settings.ryoku.$$"
      jq --argjson v "$1" '.screenPreferences = ((.screenPreferences // {}) + {wallpaper: $v})' \
        "$dms_settings" >"$tmp"
      mv -f "$tmp" "$dms_settings"
      # DMS's file watch can miss an atomic rename; ask it to re-read (best effort).
      if command -v dms >/dev/null 2>&1; then
        dms ipc call ryoku refreshSettings >/dev/null 2>&1 || true
      fi
    }

    # DMS reloads settings.json on change; an empty wallpaper screen list is
    # its documented "no wallpaper surface" value. The previous list is kept
    # so restore puts back exactly what the user had.
    cmd_dms_hide() {
      local current
      # ExecStartPost: do nothing if mpvpaper already died.
      if [[ -n "''${MAINPID:-}" ]] && ! kill -0 "$MAINPID" 2>/dev/null; then
        return 0
      fi
      [[ -f "$dms_settings" ]] || return 0
      current=$(dms_wallpaper_screens)
      [[ "$current" == "[]" ]] && return 0
      mkdir -p "$state_dir"
      printf '%s\n' "$current" >"$screens_backup"
      dms_set_wallpaper_screens '[]'
    }

    cmd_dms_restore() {
      local saved
      [[ -f "$screens_backup" ]] || return 0
      if [[ -f "$dms_settings" && "$(dms_wallpaper_screens)" == "[]" ]]; then
        saved=$(cat "$screens_backup")
        if ! jq -e 'type == "array" and length > 0' >/dev/null 2>&1 <<<"$saved"; then
          saved='["all"]'
        fi
        dms_set_wallpaper_screens "$saved"
      fi
      rm -f "$screens_backup"
    }

    # ExecCondition: a missing/moved video skips the unit (no restart loop)
    # and leaves DMS showing the static poster it already has.
    cmd_check() {
      local video=''${RYOKU_VIDEO_WALLPAPER:-}
      if [[ -z "$video" ]] || ! is_video "$video" || [[ ! -r "$video" ]]; then
        log "video wallpaper unavailable (''${video:-unset}); keeping the static wallpaper"
        cmd_dms_restore
        exit 1
      fi
      # Lock screen / DMS reference the cached poster; recreate it if the
      # cache was cleared. A failed poster must not block the video.
      (cmd_poster "$video" >/dev/null) || true
    }

    cmd_run() {
      local video=''${RYOKU_VIDEO_WALLPAPER:-}
      local profile=''${RYOKU_VIDEO_WALLPAPER_PROFILE:-balanced}
      local -a opts=(hwdec=vaapi gpu-hwdec-interop=vaapi panscan=1.0 osd-level=0 msg-level=all=error)
      local -a flags=()

      [[ -n "$video" ]] || die "RYOKU_VIDEO_WALLPAPER is not set"

      if [[ "''${RYOKU_VIDEO_WALLPAPER_LOOP:-1}" == 1 ]]; then
        opts+=(loop-file=inf)
      else
        opts+=(loop-file=no keep-open=yes)
      fi

      if [[ "''${RYOKU_VIDEO_WALLPAPER_AUDIO:-0}" == 1 ]]; then
        opts+=(aid=auto)
      else
        opts+=(aid=no)
      fi

      case "$profile" in
        economy) opts+=(vf=fps=15 profile=fast) ;;
        balanced) opts+=(vf=fps=30 profile=fast) ;;
        quality) ;;
        *)
          log "unknown profile '$profile', using balanced"
          opts+=(vf=fps=30 profile=fast)
          ;;
      esac

      # Frame-callback pause (hidden/locked) + any fullscreen toplevel.
      if [[ "''${RYOKU_VIDEO_WALLPAPER_PAUSE_COVERED:-1}" == 1 ]]; then
        flags+=(--auto-pause --auto-mode FULL)
      fi

      # mpvpaper splits --mpv-options on spaces into mpv config lines.
      exec mpvpaper "''${flags[@]}" --mpv-options "''${opts[*]}" \
        "''${RYOKU_VIDEO_WALLPAPER_OUTPUTS:-ALL}" "$video"
    }

    write_env() {
      local tmp="$env_file.$$"
      mkdir -p "$state_dir"
      {
        printf 'RYOKU_VIDEO_WALLPAPER="%s"\n' "$1"
        printf 'RYOKU_VIDEO_WALLPAPER_LOOP=%s\n' "$2"
        printf 'RYOKU_VIDEO_WALLPAPER_AUDIO=%s\n' "$3"
        printf 'RYOKU_VIDEO_WALLPAPER_PROFILE=%s\n' "$4"
        printf 'RYOKU_VIDEO_WALLPAPER_PAUSE_COVERED=%s\n' "$5"
        printf 'RYOKU_VIDEO_WALLPAPER_OUTPUTS=ALL\n'
      } >"$tmp"
      mv -f "$tmp" "$env_file"
    }

    cmd_apply() {
      local video="" loop=1 audio=0 profile=balanced pause=1 poster out
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --loop) loop=''${2:-}; shift 2 ;;
          --audio) audio=''${2:-}; shift 2 ;;
          --profile) profile=''${2:-}; shift 2 ;;
          --pause-covered) pause=''${2:-}; shift 2 ;;
          -*) usage ;;
          *) [[ -z "$video" ]] || usage; video=$1; shift ;;
        esac
      done

      [[ -n "$video" ]] || usage
      is_safe_path "$video" || die "unsupported video path: $video"
      is_video "$video" || die "unsupported video format: $video"
      [[ -r "$video" ]] || die "video not found: $video"
      if ! is_bool "$loop" || ! is_bool "$audio" || ! is_bool "$pause"; then
        die "--loop/--audio/--pause-covered take 0 or 1"
      fi
      case "$profile" in economy | balanced | quality) ;; *) die "unknown profile: $profile" ;; esac

      poster=$(cmd_poster "$video")

      # Palette + lock screen from the poster (Matugen runs once, here).
      if command -v dms >/dev/null 2>&1; then
        out=$(dms ipc call wallpaper set "$poster" 2>&1) || true
        [[ "$out" == SUCCESS* ]] || log "dms: $out"
      else
        log "dms not found; palette not updated"
      fi

      write_env "$video" "$loop" "$audio" "$profile" "$pause"

      # Video A → B: show the new poster over A before restarting, so the
      # switch never exposes an empty background.
      if systemctl --user is-active --quiet "$unit"; then
        cmd_dms_restore
        sleep 1
      fi
      systemctl --user reset-failed "$unit" 2>/dev/null || true
      systemctl --user restart "$unit"
      printf '%s\n' "$poster"
    }

    # Back to a static wallpaper: DMS (already set by the caller) is shown
    # over the video first, then mpvpaper is stopped.
    cmd_stop() {
      cmd_dms_restore
      rm -f "$env_file"
      if systemctl --user is-active --quiet "$unit"; then
        sleep 1
        systemctl --user stop "$unit"
      fi
      systemctl --user reset-failed "$unit" 2>/dev/null || true
    }

    cmd_status() {
      if systemctl --user is-active --quiet "$unit"; then
        echo "active"
      else
        echo "inactive"
      fi
      [[ -f "$env_file" ]] && cat "$env_file"
      return 0
    }

    [[ $# -ge 1 ]] || usage
    sub=$1
    shift
    case "$sub" in
      apply) cmd_apply "$@" ;;
      stop) cmd_stop ;;
      poster) [[ $# -eq 1 ]] || usage; cmd_poster "$1" ;;
      status) cmd_status ;;
      check) cmd_check ;;
      run) cmd_run ;;
      dms-hide) cmd_dms_hide ;;
      dms-restore) cmd_dms_restore ;;
      *) usage ;;
    esac
  '';

  meta = {
    description = "Ryoku video wallpaper runtime (mpvpaper + DMS poster/palette)";
    platforms = lib.platforms.linux;
    mainProgram = "ryoku-video-wallpaper";
  };
}
