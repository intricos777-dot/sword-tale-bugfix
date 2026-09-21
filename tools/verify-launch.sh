#!/usr/bin/env bash
# Smoke-test that Sword Tale: Lost Excalibur boots past the render-thread stage
# where ST-001 kills it. Runs the game in its own Proton prefix with the repo's
# recommended environment, watches for the UE log and a game window, then exits.
#
# Usage:
#   ./verify-launch.sh                # one boot attempt, up to 240 s
#   ATTEMPTS=3 ./verify-launch.sh     # best-of-N (useful after config changes)
#   TIMEOUT=180 ./verify-launch.sh    # custom watch window
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
  rm -f "$LOGDIR/Logs/SwordTale.log"
  echo "[attempt $n] launching ..."
  if command -v gamemoderun >/dev/null 2>&1; then
    gamemoderun "$RUNNER" -- "$PROTON" run SwordTale.exe -nomovie -novsync -malloc=system > /tmp/swordtale-verify.log 2>&1 &
  else
    "$RUNNER" -- "$PROTON" run SwordTale.exe -nomovie -novsync -malloc=system > /tmp/swordtale-verify.log 2>&1 &
  fi
  local pid=$! start; start=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    local el=$(( $(date +%s) - start ))
    if [ "$el" -ge "$TIMEOUT" ]; then break; fi
    if [ -f "$LOGDIR/Logs/SwordTale.log" ]; then
      local w; w=$(xdotool search --name -i swordtale 2>/dev/null | head -1 || true)
      echo "PASS: game log appeared at ${el}s${w:+ and window $w up} (attempt $n)"
      kill "$pid" 2>/dev/null; sleep 2; pkill -f "SwordTale-Win64" 2>/dev/null || true
      return 0
    fi
    sleep 2
  done
  if kill -0 "$pid" 2>/dev/null; then
    echo "FAIL: no progress in ${TIMEOUT}s (attempt $n)"; kill "$pid" 2>/dev/null; sleep 2; pkill -f "SwordTale-Win64" 2>/dev/null || true
  else
    echo "FAIL: process exited early (attempt $n)"
  fi
  # surface crash artifact if any appeared
  local c; c=$(ls -dt "$LOGDIR"/Crashes/UE4CC-* 2>/dev/null | head -1 || true)
  [ -n "$c" ] && { echo "    crash artifact: $c"; grep -a "ErrorMessage" "$c/CrashContext.runtime-xml" 2>/dev/null | head -2 | sed 's/^/    /'; }
  # surface engine log tail if one exists now
  [ -f "$LOGDIR/Logs/SwordTale.log" ] && { echo "    log tail:"; tail -5 "$LOGDIR/Logs/SwordTale.log" | sed 's/^/    /'; }
  return 1
}

pass=0
for n in $(seq 1 "$ATTEMPTS"); do
  if boot_attempt "$n"; then pass=1; break; fi
  sleep 3
done
[ "$pass" -eq 1 ] && echo "RESULT: PASS" && exit 0
echo "RESULT: FAIL — see docs/DIAGNOSIS.md and open an issue with tools/collect-crash-info.sh output."
exit 1