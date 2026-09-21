#!/usr/bin/env bash
# Install optimized Unreal config templates into the Sword Tale: Lost Excalibur
# Proton prefix. Backs up any existing files first. Safe to re-run.
set -euo pipefail

GAME_APPID="${GAME_APPID:-3305630}"
STEAM_ROOT="${STEAM_ROOT:-$HOME/.local/share/Steam}"
PREFIX_DIR="$STEAM_ROOT/steamapps/compatdata/$GAME_APPID"
CFG_DIR="$PREFIX_DIR/pfx/drive_c/users/steamuser/AppData/Local/SwordTale/Saved/Config/WindowsNoEditor"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES=(Engine.ini Scalability.ini GameUserSettings.ini)

die() { echo "error: $*" >&2; exit 1; }

if [ ! -d "$PREFIX_DIR/pfx" ]; then
  die "Proton prefix not found at $PREFIX_DIR. Has the game been launched at least once?"
fi
mkdir -p "$CFG_DIR"

for t in "${TEMPLATES[@]}"; do
  src="$SCRIPT_DIR/$t"
  dst="$CFG_DIR/$t"
  [ -f "$src" ] || { echo "skip: template missing $src"; continue; }
  if [ -f "$dst" ]; then
    cp -v "$dst" "$dst.bak-$(date +%Y%m%d%H%M%S)" || true
  fi
  cp -v "$src" "$dst"
done

echo
echo "done. Next: launch the game via Steam with the recommended launch options"
echo "from linux/launch-options.txt, or run tools/verify-launch.sh to smoke-test."
echo "To undo: $(dirname "$0")/revert-configs.sh"