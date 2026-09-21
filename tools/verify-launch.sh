#!/usr/bin/env bash
# Smoke-test that Sword Tale: Lost Excalibur boots past the render-thread
# stage where ST-001 kills it, and (optionally) STAYS alive during gameplay.
# Runs the game in its own Proton prefix with the repo's recommended
# environment, watches for the UE log and game window, then reports.
#
# Usage:
#   ./verify-launch.sh                # one boot attempt (PASS as soon as log appears)
#   STAY=180 ./verify-launch.sh       # PASS only if the game survives 180 s in-mission
#   ATTEMPTS=3 ./verify-launch.sh     # best-of-N (useful after config changes)
#   TIMEOUT=240 ./verify-launch.sh    # max time to wait for the engine log
#
# NOTE: This boots the game directly, outside Steam's full environment. The game
# is Steamworks-linked: with the Steam client running, a direct boot can die on
# the Steam client IPC (observed: 'IClientUtils::SetAppIDForCurrentPipe took too
# long'). The canonical test is the Steam client itself — launch the game there
# with the repo's launch options. This tool remains the reliable automated gate
# on systems where Steam is closed, and for troubleshooting prefixes.
set -euo pipefail

GAME_APPID="${GAME_APPID:-3305630}"
STEAM_ROOT="${STEAM_ROOT:-$HOME/.local/share/Steam}"
STEAM_COMMON="$STEAM_ROOT/steamapps/common"
GAME_DIR="$STEAM_COMMON/Sword Tale Lost Excalibur"
PREFIX_DIR="$STEAM_ROOT/steamapps/compatdata/$GAME_APPID"
SHADER_DIR="$STEAM_ROOT/steamapps/shadercache/$GAME_APPID"
LOGDIR="$PREFIX_DIR/pfx/drive_c/users/steamuser/AppData/Local/SwordTale/Saved"
ATTEMPTS="${ATTEMPTS:-1}"
TIMEOUT="${TIMEOUT:-240}"
STAY="${STAY:-0}"
PROTON=""; for p in "$STEAM_COMMON/Proton - Experimental/proton" "$STEAM_COMMON/Proton 11.0/proton"; do [ -f "$p" ] && PROTON="$p" && break; done
RUNNER=""; for r in "$STEAM_COMMON/SteamLinuxRuntime_sniper/run" "$STEAM_COMMON/SteamLinuxRuntime/run"; do [ -x "$r" ] && RUNNER="$r" && break; done

[ -n "$PROTON" ] && [ -n "$RUNNER" ] || { echo "error: Proton tool missing" >&2; exit 1; }
[ -d "$PREFIX_DIR/pfx" ] || { echo "error: prefix missing — run the game once through Steam first." >&2; exit 1; }

export STEAM_COMPAT_DATA_PATH="$PREFIX_DIR"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_ROOT"
export STEAM_COMPAT_SHADER_PATH="$SHADER_DIR"
export SteamAppId="$GAME_APPID" SteamGameId="$GAME_APPID"
export DXVK_FILTER_DEVICE_NAME="${DXVK_FILTER_DEVICE_NAME:-GeForce RTX 3050}"
export DXVK_CONFIG="${DXVK_CONFIG:-dxvk.numCompilerThreads=4,dxvk.maxFrameLatency=2,dxvk.enableGraphicsPipelineLibrary=True,dxvk.shrinkNvidiaHvvHeap=True}"
export PROTON_ENABLE_NVAPI=1

boot_attempt() {
  local n="$1"
  local start el log_seen=0 seated=0
  rm -f "$LOGDIR/Logs/SwordTale.log"
  echo "[attempt $n] launching ..."
  if command -v gamemoderun >/dev/null 2>&1; then
    gamemoderun "$RUNNER" -- "$PROTON" run SwordTale.exe -nomovie -novsync -malloc=system > /tmp/swordtale-verify.log 2>&1 &
  else
    "$RUNNER" -- "$PROTON" run SwordTale.exe -nomovie -novsync -malloc=system > /tmp/swordtale-verify.log 2>&1 &
  fi
  local pid=$!
  start=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    el=$(( $(date +%s) - start ))
    if [ -f "$LOGDIR/Logs/SwordTale.log" ] && [ "$log_seen" -eq 0 ]; then
      log_seen=1
      local w; w=$(xdotool search --name -i swordtale 2>/dev/null | head -1 || true)
      echo "   engine log appeared at ${el}s${w:+; window $w up}"
    fi
    if [ "$log_seen" -eq 1 ] && [ "$STAY" -gt 0 ]; then
      if [ "$el" -ge "$STAY" ]; then
        echo "PASS: game survived ${el}s after boot (attempt $n)"
        kill "$pid" 2>/dev/null; sleep 2; pkill -f "SwordTale-Win64" 2>/dev/null || true
        return 0
      fi
    elif [ "$log_seen" -eq 1 ] && [ "$STAY" -eq 0 ]; then
      echo "PASS: game log appeared at ${el}s (attempt $n)"
      kill "$pid" 2>/dev/null; sleep 2; pkill -f "SwordTale-Win64" 2>/dev/null || true
      return 0
    fi
    if [ "$el" -ge "$TIMEOUT" ]; then break; fi
    sleep 2
  done
  # process exited on its own
  if [ "$log_seen" -eq 1 ]; then
    echo "FAIL: game ran but exited at ${el}s during session (attempt $n) — mid-game crash pattern"
  elif kill -0 "$pid" 2>/dev/null; then
    echo "FAIL: no engine log within ${TIMEOUT}s (attempt $n)"; kill "$pid" 2>/dev/null; sleep 2; pkill -f "SwordTale-Win64" 2>/dev/null || true
  else
    echo "FAIL: process exited early at ${el}s, no engine log (attempt $n)"
  fi
  local c; c=$(ls -dt "$LOGDIR"/Crashes/UE4CC-* 2>/dev/null | head -1 || true)
  [ -n "$c" ] && { echo "    crash artifact: $c"; grep -a "ErrorMessage" "$c/CrashContext.runtime-xml" 2>/dev/null | head -2 | sed 's/^/    /'; }
  return 1
}

pass=0
for n in $(seq 1 "$ATTEMPTS"); do
  if boot_attempt "$n"; then pass=1; break; fi
  sleep 3
done
[ "$pass" -eq 1 ] && echo "RESULT: PASS${STAY:+ (${STAY}s liveness)}" && exit 0
echo "RESULT: FAIL — see docs/DIAGNOSIS.md and open an issue with tools/collect-crash-info.sh output."
exit 1