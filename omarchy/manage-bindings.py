#!/usr/bin/env python3
"""Install/remove only the marked Ryoku block; preserve other user overrides."""
import os
import sys
import tempfile
from pathlib import Path
import shutil
from datetime import datetime, timezone

root = Path(__file__).resolve().parent
config = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "hypr"
target = config / "bindings.lua"
overlay = config / "ryoku-bindings.lua"
state = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "ryoku-omarchy" / "backups"
begin = "-- BEGIN RYOKU MANAGED SHORTCUTS"
end = "-- END RYOKU MANAGED SHORTCUTS"
block = begin + '\n' + 'dofile((os.getenv("XDG_CONFIG_HOME") or os.getenv("HOME") .. "/.config") .. "/hypr/ryoku-bindings.lua")' + '\n' + end + '\n'
def atomic(path, data):
    fd, name = tempfile.mkstemp(prefix=".ryoku-", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(data)
        if path.exists():
            os.chmod(name, path.stat().st_mode & 0o777)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)

def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("apply", "remove"):
        raise ValueError("usage: manage-bindings.py apply|remove")
    if target.is_symlink() or overlay.is_symlink() or not target.is_file():
        raise ValueError("refusing missing/symlinked bindings.lua or overlay")
    original = target.read_text(encoding="utf-8")
    source = (root / "bindings.lua").read_text(encoding="utf-8")
    current = overlay.read_text(encoding="utf-8") if overlay.exists() else None
    if (begin in original or end in original) and original.count(block) != 1:
        raise ValueError("unexpected managed block; inspect manually")
    clean = original.replace(block, "")
    if current is not None and current != source and block not in original:
        raise ValueError("existing unmanaged ryoku-bindings.lua")
    if sys.argv[1] == "remove" and block not in original:
        print("No managed shortcuts to remove")
        return
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    backup = state / stamp
    backup.mkdir(parents=True)
    shutil.copy2(target, backup / target.name)
    if overlay.exists():
        shutil.copy2(overlay, backup / overlay.name)
    if sys.argv[1] == "apply":
        if shutil.which("luac"):
            import subprocess
            subprocess.run(["luac", "-p", str(root / "bindings.lua")], check=True)
        atomic(overlay, source)
        candidate = clean + ("" if clean.endswith("\n") else "\n") + block
        atomic(target, candidate)
    else:
        atomic(target, clean)
        # Preserve even an edited overlay in the backup and on disk; no longer sourced.
    print(f"Backup: {backup}")
if __name__ == "__main__":
    main()
