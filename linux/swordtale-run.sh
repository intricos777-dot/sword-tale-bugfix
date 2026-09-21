#!/usr/bin/env bash
# Standalone runner for Sword Tale: Lost Excalibur outside Steam (Lutris/Heroic,
# or manual Proton invocations). Uses the SAME prefix Steam created, so saves and
# settings carry over. Steam-launch is still preferred (ST-002).
#
# Usage:
#   ./swordtale-run.sh                 # run with recommended env, default args
#   GAME_ARGS="-resx=1280 -resy=720 -nomovie" ./swordtale-run.sh
set -euo pipefail

GAME_APPID="${GAME_APPID:-3305630}"
STEAM_ROOT="${STEAM_ROOT:-$HOME/.local/share/Steam}"
STEAM_COMMON="$STEAM_ROOT/steamapps/common"
GAME_DIR="$STEAM_COMMON/Sword Tale Lost Excalibur"
PREFIX_DIR="$STEAM_ROOT/steamapps/compatdata/$GAME_APPID"
SHADER_DIR="$STEAM_ROOT/steamapps/shadercache/$GAME_APPID"

# Pick first available Proton tool.
PROTON=""
for p in "$STEAM_COMMON/Proton - Experimental/proton" "$STEAM_COMMON/Proton 11.0/proton" "$STEAM_COMMON/Proton Hotfix/proton"; do
  [ -f "$p" ] && PROTON="$p" && break
done
RUNNER=""
for r in "$STEAM_COMMON/SteamLinuxRuntime_sniper/run" "$STEAM_COMMON/SteamLinuxRuntime/run"; do
  [ -x "$r" ] && RUNNER="$r" && break
done
[ -n "$PROTON" ] && [ -n "$RUNNER" ] || { echo "error: Proton/SteamLinuxRuntime not found under $STEAM_COMMON" >&2; exit 1; }
[ -d "$PREFIX_DIR/pfx" ] || { echo "error: prefix missing — launch the game once through Steam first." >&2; exit 1; }

export STEAM_COMPAT_DATA_PATH="$PREFIX_DIR"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_ROOT"
export STEAM_COMPAT_SHADER_PATH="$SHADER_DIR"
export SteamAppId="$GAME_APPID"
export SteamGameId="$GAME_APPID"

# Recommended translation layer + engine settings (see docs/DIAGNOSIS.md).
export DXVK_FILTER_DEVICE_NAME="${DXVK_FILTER_DEVICE_NAME:-GeForce RTX 3050}"
export DXVK_CONFIG="${DXVK_CONFIG:-dxvk.numCompilerThreads=4,dxvk.maxFrameLatency=2,dxvk.enableGraphicsPipelineLibrary=True,dxvk.shrinkNvidiaHvvHeap=True}"
export PROTON_ENABLE_NVAPI=1

cd "$GAME_DIR"
# shellcheck disable=SC2086
if command -v gamemoderun >/dev/null 2>&1; then
  exec gamemoderun "$RUNNER" -- "$PROTON" run SwordTale.exe ${GAME_ARGS:--nomovie -novsync -malloc=system}
else
  exec "$RUNNER" -- "$PROTON" run SwordTale.exe ${GAME_ARGS:--nomovie -novsync -malloc=system}
fi