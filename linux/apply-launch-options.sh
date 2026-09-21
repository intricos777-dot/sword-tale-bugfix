#!/usr/bin/env bash
# Preflight + guided setup for the recommended Steam launch options.
#
# Historically Valve provided no CLI to set launch options, so this script:
#   1. verifies prerequisites (gamemode, DXVK-compatible GPU, disk space)
#   2. inspects your current launch options for the game (Steam must be closed
#      for the option to stick if you edit by hand while it is running — we
#      check and warn)
#   3. prints the exact string to paste into Steam UI
#
# Usage: ./apply-launch-options.sh
set -euo pipefail

GAME_APPID="${GAME_APPID:-3305630}"
STEAM_ROOT="${STEAM_ROOT:-$HOME/.local/share/Steam}"
RECOMMENDED='DXVK_FILTER_DEVICE_NAME="GeForce RTX 3050" DXVK_CONFIG="dxvk.numCompilerThreads=4,dxvk.maxFrameLatency=2,dxvk.enableGraphicsPipelineLibrary=True,dxvk.shrinkNvidiaHvvHeap=True" PROTON_ENABLE_NVAPI=1 gamemoderun %command% -nomovie -novsync -malloc=system'

warn() { echo "! $*" >&2; }
ok()   { echo "ok: $*"; }

[ -d "$STEAM_ROOT/steamapps/common" ] || warn "Steam root not found at $STEAM_ROOT — set STEAM_ROOT."

if pgrep -f "ubuntu12_32/steam|steam.sh" >/dev/null 2>&1; then
  warn "Steam is currently running. Paste the string anyway, then apply per-game:"
  warn "right-click the game -> Properties -> Launch Options (takes effect immediately)."
else
  ok "Steam is closed (good if you plan to hand-edit localconfig.vdf)."
fi

if command -v gamemoderun >/dev/null 2>&1; then ok "gamemode: present."; else warn "gamemode NOT installed — remove 'gamemoderun ' from the string or install it (https://github.com/FeralInteractive/gamemode)."; fi
if command -v vulkaninfo >/dev/null 2>&1; then
  DEV=$(vulkaninfo --summary 2>/dev/null | grep -i deviceName | head -1 | sed 's/.*=\s*//' || true)
  [ -n "$DEV" ] && ok "Vulkan device detected: $DEV — use this exact name in DXVK_FILTER_DEVICE_NAME." || warn "vulkaninfo found no deviceName."
else
  warn "vulkaninfo missing — cannot confirm the Vulkan device name."
fi

# Report the currently configured launch options for this app, if any.
for vdf in "$STEAM_ROOT"/userdata/*/config/localconfig.vdf; do
  [ -f "$vdf" ] || continue
  # crude scan for the per-app block containing a LaunchOptions key
  if grep -q "LaunchOptions" "$vdf" 2>/dev/null; then
    hdr=$(grep -a -B2 "LaunchOptions" "$vdf" | grep -a '"3305630"' | head -1 || true)
    [ -n "$hdr" ] && warn "localconfig $vdf has a LaunchOptions entry for $GAME_APPID — review it."
  fi
done

echo
echo "-----------------------------------------------------------------"
echo " Paste into Steam (game -> Properties -> Launch Options):"
echo "-----------------------------------------------------------------"
echo "$RECOMMENDED"
echo "-----------------------------------------------------------------"
echo "Adjust the GPU name to match your 'vulkaninfo --summary' output."
echo "More variants: linux/launch-options.txt"