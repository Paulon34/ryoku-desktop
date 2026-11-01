# Ryoku settings (declarative)

Source of truth for Ryoku Desktop preferences that the future
**Ryoku Settings** GUI will edit.

## Files

| Path | Role |
|---|---|
| `ryoku/settings.json` | Canonical config (Git-versioned) |
| `ryoku/schema/settings.schema.json` | JSON Schema for `schemaVersion` |
| `ryoku/lib.nix` | Shared Nix loader / helpers |
| `modules/ryoku.nix` | NixOS reader (infrastructure) |
| `home/ryoku.nix` | Home Manager reader (infrastructure) |

## Contract

1. **`ryoku/settings.json` is the declarative source of truth** for any
   setting that has been migrated to Ryoku Settings.
2. **NixOS / Home Manager only read and project known keys.** They never
   invent arbitrary Nix from the GUI, and they never write this file.
3. **`null` (or an absent key) means “do not override”.** Existing
   `home/*.nix` / `modules/*.nix` / DMS runtime config continues to apply.
4. **`~/.config/DankMaterialShell/settings.json`** remains for DMS shell
   settings that are not yet migrated (or pure runtime state). One key must
   not have two writers.
5. **Runtime Matugen output** (`~/.config/ryoku/palette.json`, `palette.css`)
   is separate from this declarative file. Do not mix them.
6. **Do not edit `/nix/store`.** Apply changes by updating this JSON (later
   via GUI) and rebuilding through the normal flake path.

## Canonical JSON format (schemaVersion 1)

`ryoku/settings.json` is **machine-written** by SettingsStore.

Canonical form = Qt 6 `QJsonDocument::toJson(QJsonDocument::Indented)`:

- 4-space indentation;
- no blank lines between sections;
- object keys emitted in **sorted** order (`QJsonObject::keys()`);
- trailing newline.

Do **not** depend on key order for semantics — readers must treat JSON
objects as unordered. Manual pretty-printing / blank lines will be
discarded on the next Save.

The first Save of a hand-edited (pre-canonical) file may rewrite
formatting once. After that, diffs must reflect **semantic** changes
only. SettingsStore skips the write when on-disk bytes already match
the canonical serialization.

## Flatpak apps (schemaVersion 1)

`apps.flatpakDeclared` is the **only** source of truth for Flatpaks managed
by Ryoku. `modules/flatpak.nix` projects that array to
`services.flatpak.packages` (nix-flatpak).

- Store **application IDs** (e.g. `"org.cutwire.Drift"`), sorted alphabetically,
  unique — SettingsStore enforces this on Save for stable Git diffs.
- GUI “Add to Ryoku” / “Remove from Ryoku” only edits this list.
- Install / uninstall / `nixos-rebuild` are **not** performed by the GUI yet
  (Needs Apply after Save).

## Wallpaper id (schemaVersion 1)

`appearance.wallpaper` stores a **basename** of a file shipped in
`assets/wallpapers/` (Home Manager installs that tree to
`~/.local/share/wallpapers`). Example: `"1.jpg"`.

- Do **not** persist `/home/...` absolute paths.
- Live preview uses the existing DMS IPC:
  `dms ipc call wallpaper set <absolute-path>`
  (same as `scripts/change-wallpaper.sh`).
- Declarative HM projection of wallpaper is not yet wired (Phase 7D+).

## Video wallpaper (schemaVersion 1)

`appearance.wallpaper` stays a **static image**. A video is selected with:

```json
"wallpaperType": "video",
"videoWallpaper": {
    "file": "rain.mp4",
    "loop": true,
    "audio": false,
    "profile": "balanced",
    "pauseWhenCovered": true
}
```

- `wallpaperType` null / missing / `"image"` → current behavior (DMS image).
  Older files need no change; image-only saves add no video keys.
- `videoWallpaper.file` is a gallery basename (`.mp4`, `.webm`, `.mkv`,
  `.mov`) in `assets/wallpapers/`. GIF is not supported (no hardware decode).
- Option nulls mean defaults: loop on, audio off, `balanced`, pause on.
  `economy` ≈ 15 fps, `balanced` ≈ 30 fps, `quality` = source frame rate;
  all decode on the Intel iGPU via VA-API.
- Live like `wallpaper` (not in the Apply hash). Runtime path:
  `ryoku-video-wallpaper apply` extracts one poster frame (cached in
  `~/.cache/ryoku/video-posters`), sets it as the DMS wallpaper (Matugen
  palette + DMS lock screen), writes `~/.local/state/ryoku/video-wallpaper.env`
  and restarts `ryoku-video-wallpaper.service` (mpvpaper, `home/video-wallpaper.nix`).
- While the video runs, Ryoku sets DMS `screenPreferences.wallpaper = []`
  so only mpvpaper draws the background, and restores the previous value when
  the unit stops (the one DMS key Ryoku writes at runtime).
- Missing / moved video → the unit is skipped at start and the poster stays
  as a static wallpaper. Selecting an image (or `$mod+W`) stops the video.
- `appearance.loginWallpaper` (SDDM) is unaffected and image-only.

## Weather location (schemaVersion 1)

`weather.location` is a place name (`"City"` or `"City, Country"`) that DMS
resolves with its built-in Open-Meteo geocoding. Home Manager projects it on
activation:

- `null` / missing / blank → DMS `weatherEnabled = false`: weather hidden,
  never fetched, no fallback city.
- string → DMS `session.json` `weatherLocation = <value>`,
  `weatherCoordinates = ""`, `weatherEnabled = true`, `useAutoLocation = false`.

This is a personal value: never hardcode it in `home/*.nix` / `modules/*.nix`
or as a schema default. Ryoku is the only writer of these DMS keys; edits made
in DMS Settings → Time & Weather are overwritten on the next activation.

## Phase 7D limitations (next)

- No Flatpak install/uninstall from the GUI.
- No Flathub search / screenshots / remote metadata.
- No Polkit / `nixos-rebuild` / Apply pipeline from Settings.
- No Nix package or AppImage management.
- Wallpaper runtime rollback still incomplete (from 7C).

## Phase 7C limitations (historical)

- **Wallpaper live preview** applies immediately via DMS; **Reset Changes** and
  app close do **not** roll back the runtime wallpaper to the last saved JSON
  value.
- **dynamicColors / animations / transparency** persist to JSON only
  (**Needs Apply**).
- No arbitrary wallpaper import — Ryoku gallery basenames only.
- No Polkit, `nixos-rebuild`, HM switch, or Git commit/push from the GUI.

## schemaVersion

Current: **1**

Future migrations (`1 → 2 → 3`) will transform the JSON and bump
`schemaVersion`. No migration engine ships in 7A; the field exists so
eval can reject incompatible majors early.

## Unknown keys

Sections allow additional properties so future GUI fields are not
destroyed by older readers. Nix only consumes keys it understands;
unknown keys are preserved in the file for later schema versions.
