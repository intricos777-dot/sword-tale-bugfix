#!/usr/bin/env bash
# Restore the prefix's previous Unreal config files (created by install-configs.sh).
set -euo pipefail

GAME_APPID="${GAME_APPID:-3305630}"
STEAM_ROOT="${STEAM_ROOT:-$HOME/.local/share/Steam}"
CFG_DIR="$STEAM_ROOT/steamapps/compatdata/$GAME_APPID/pfx/drive_c/users/steamuser/AppData/Local/SwordTale/Saved/Config/WindowsNoEditor"
TEMPLATES=(Engine.ini Scalability.ini GameUserSettings.ini)

restored=0
for t in "${TEMPLATES[@]}"; do
  dst="$CFG_DIR/$t"
  bak=$(ls -1 "$dst".bak-* 2>/dev/null | tail -1 || true)
  if [ -n "$bak" ] && [ -f "$bak" ]; then
    cp -v "$bak" "$dst"
    rm -v "$bak"
    restored=$((restored+1))
  else
    [ -f "$dst" ] && rm -v "$dst" || true
  fi
done
[ "$restored" -eq 0 ] && echo "nothing to restore (no templates had been applied)."