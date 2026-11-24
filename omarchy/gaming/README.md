# Ryoku Games — per-app dedicated GPU (experimental)

Optional **NVIDIA PRIME Render Offload** wrapper for hybrid Intel/NVIDIA laptops: keep Omarchy/Hyprland on the integrated GPU and **request** the dedicated GPU for selected games. No driver, BIOS, system compositor or global-session changes.

**Validation status:** the Minecraft Flatpak (`com.mojang.Minecraft`) override and matching NVIDIA Flatpak runtime were observed on a development notebook, but the post-change Minecraft F3 GPU display and actual NVIDIA rendering are **not yet verified**. CurseForge AppImage is likewise pending hardware validation.

References: [NVIDIA PRIME Render Offload](https://download.nvidia.com/XFree86/Linux-x86_64/550.78/README/primerenderoffload.html), [Flatpak command reference](https://docs.flatpak.org/en/latest/flatpak-command-reference.html).

## Native games and AppImages

From `omarchy/`, install the opt-in wrapper as a regular user:

```bash
install -Dm755 gaming/ryoku-game "$HOME/.local/bin/ryoku-game"
"$HOME/.local/bin/ryoku-game" /path/to/game [arguments...]
```

For CurseForge, replace the executable with the actual AppImage path and preserve the arguments **your existing launcher requires**. Do not add `--no-sandbox` unless it is already required and understood. The wrapper sets offload variables only for the launched process tree. It never edits `.desktop` shortcuts or modifies drivers. Remove the wrapper with `rm -- "$HOME/.local/bin/ryoku-game"` if you have not modified it.

## Official Minecraft Flatpak

Check your application ID with `flatpak list --app`. The development notebook uses `com.mojang.Minecraft`; `minecraft-launcher` is **not** its host executable.

```bash
mkdir -p "$HOME/.local/state/ryoku-omarchy"
flatpak override --user --show com.mojang.Minecraft \
  > "$HOME/.local/state/ryoku-omarchy/minecraft-overrides-before.txt"

flatpak override --user \
  --env=__NV_PRIME_RENDER_OFFLOAD=1 \
  --env=__GLX_VENDOR_LIBRARY_NAME=nvidia \
  --env=__VK_LAYER_NV_optimus=NVIDIA_only \
  com.mojang.Minecraft
```

Close Minecraft and its launcher, reopen, and use the in-game **F3** renderer and `nvidia-smi` to **verify** actual GPU choice. If F3 still shows Intel, investigate whether the game Java process inherited the variables and whether the Flatpak NVIDIA runtime is installed (`flatpak --gl-drivers`, `flatpak list --runtime`).

To remove only these three per-app environment preferences (this does not automatically restore any previous values; refer to your saved override snapshot):

```bash
flatpak override --user \
  --unset-env=__NV_PRIME_RENDER_OFFLOAD \
  --unset-env=__GLX_VENDOR_LIBRARY_NAME \
  --unset-env=__VK_LAYER_NV_optimus \
  com.mojang.Minecraft
```

## Steam

Put this string inside the game's **Steam launch options**; `%command%` is not a Bash command:

```text
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only %command%
```

Performance and power outcomes require game-specific testing. Integrated and dedicated GPUs may both draw some power depending on outputs and hardware routing.

**No secrets, user paths or personal settings are bundled.**
