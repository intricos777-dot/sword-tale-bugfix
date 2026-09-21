#!/usr/bin/env bash
# Bundle everything useful for a bug report (forum post, GitHub issue, or a
# respectful message to the developer via the Steam discussions hub).
# Prints a self-contained report to stdout; optionally saves it too.
#
# Usage: ./collect-crash-info.sh [output.md]
set -euo pipefail

GAME_APPID="${GAME_APPID:-3305630}"
STEAM_ROOT="${STEAM_ROOT:-$HOME/.local/share/Steam}"
LOGDIR="$STEAM_ROOT/steamapps/compatdata/$GAME_APPID/pfx/drive_c/users/steamuser/AppData/Local/SwordTale/Saved"
OUT="${1:-}"

report() {
  echo "# Sword Tale: Lost Excalibur — crash report"
  echo
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo "## System"
  uname -a 2>/dev/null | sed 's/^/ - /'
  nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>/dev/null | sed 's/^/ - GPU: /' || true
  free -m | head -2 | sed 's/^/ - /'
  echo " - Vulkan: $(vulkaninfo --summary 2>/dev/null | grep -i deviceName | head -1 | sed 's/^[[:space:]]*//')" || true
  echo
  echo "## Steam / Proton"
  ls "$STEAM_ROOT/steamapps/common/" 2>/dev/null | grep -i proton | sed 's/^/ - tool: /' || true
  grep -a "$GAME_APPID" "$STEAM_ROOT/logs/console-linux.txt" 2>/dev/null | tail -5 | sed 's/^/ - steam: /' || true
  echo
  echo "## Crash artifacts"
  shopt -s nullglob
  for c in "$LOGDIR"/Crashes/UE4CC-*; do
    echo "### $c"
    for f in CrashContext.runtime-xml UE4Minidump.dmp; do
      [ -f "$c/$f" ] && ls -l "$c/$f" 2>/dev/null | awk '{print " - file: "$NF" ("$5" bytes)"}'
    done
    [ -f "$c/CrashContext.runtime-xml" ] && grep -a -E "ErrorMessage|EngineVersion|PrimaryGPUBrand|TotalPhysicalGB|AvailablePhysical" "$c/CrashContext.runtime-xml" | sed 's/^/ - /'
  done
  echo
  echo "## Game logs"
  for l in "$LOGDIR"/Logs/SwordTale*.log; do
    [ -f "$l" ] && { echo " - $l: $(wc -l < "$l") lines"; tail -15 "$l" | sed 's/^/   /'; }
  done
  [ -f /tmp/swordtale-verify.log ] && { echo " - runner log tail:"; tail -10 /tmp/swordtale-verify.log | sed 's/^/   /'; }
  echo
  echo "## Notes for the developer (UTCC-DGS)"
  echo " - Engine: Unreal 4.18.3 (CL-3832480). Crash signature: RenderingThread.cpp:1015"
  echo "   'GameThread timed out waiting for RenderThread after 30.00 secs' (ST-001)."
  echo " - Likely contributors: boot-time shader compilation, VR-runtime init, movie"
  echo "   playback, texture-streaming defaults on 8 GB / 4 GB VRAM systems."
}

if [ -n "$OUT" ]; then
  report | tee "$OUT"
  echo "saved to: $OUT"
else
  report
fi