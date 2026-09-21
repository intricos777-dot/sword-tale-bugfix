#!/usr/bin/env bash
# steam-pause-watcher
#
# Pauses all mining services while Steam (or a Steam game) is running,
# and reliably RESTARTS ALL of them once Steam fully exits.
# This frees CPU/GPU for gaming, then returns the full hashing power
# of the forge the moment the game is done.
#
# Extended (0.1.2): also pauses memory-hungry host daemons that starve the
# GPU driver mid-game on low-RAM hosts (see sword-tale-bugfix ST-001c):
#   - bchn.service   Bitcoin Cash node   (user scope, ~1.4 GB RSS)
#   - ollama.service local LLM server    (system scope via sudo -n, ~0.8 GB RSS)
# Frees ~2.2 GB of RAM for the game session; both are auto-resumed on exit.
#
# Hardened against the common failure modes:
#   - self-heals on watcher restart (no lost "resume" events)
#   - dynamic Steam library discovery from libraryfolders.vdf
#   - clears systemd start-limits before starting a miner
#   - verifies every miner actually rose after resume

set -u

MINER_SERVICES="mine-btc.service mine-ltc.service mine-doge.service mine-gpu.service"
AUX_SERVICES="bchn.service ollama.service"
CHECK_INTERVAL=15
GRACE_ACTIVATE=90          # seconds allowed for all miners to come back
STEAM_ROOT="$HOME/.local/share/Steam"
STEAM_PIDFILE="$HOME/.steam/steam.pid"
LAST_STATE="unknown"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }
LOG_FILE="$HOME/miners/logs/steam-pause.log"
exec >>"$LOG_FILE" 2>&1

# -------- Steam library discovery -------------------------------------
# Read all library mount points from libraryfolders.vdf so game-process
# detection keeps working no matter where games are installed.
STEAM_LIBRARIES=()
if [ -f "$STEAM_ROOT/steamapps/libraryfolders.vdf" ]; then
    while IFS= read -r p; do
        [ -n "$p" ] && STEAM_LIBRARIES+=("$p")
    done < <(sed -n 's/.*"path"[[:space:]]*"\([^"]*\)".*/\1/p' \
                "$STEAM_ROOT/steamapps/libraryfolders.vdf")
fi
STEAM_LIBRARIES+=("$STEAM_ROOT")
# dedupe
STEAM_LIBRARIES=($(printf '%s\n' "${STEAM_LIBRARIES[@]}" | sort -u))

# -------- detection ----------------------------------------------------
game_running() {
    local lib
    for lib in "${STEAM_LIBRARIES[@]:-}"; do
        pgrep -f "$lib/steamapps/common/" >/dev/null 2>&1 && return 0
    done
    # Proton / Wine prefixes for Steam games
    pgrep -f "steamapps/compatdata/" >/dev/null 2>&1 && return 0
    return 1
}

steam_client_running() {
    pgrep -x steam >/dev/null 2>&1 && return 0
    pgrep -x steamwebhelper >/dev/null 2>&1 && return 0
    pgrep -f "steam-runtime-launcher" >/dev/null 2>&1 && return 0
    pgrep -f "$STEAM_ROOT/steam.sh" >/dev/null 2>&1 && return 0
    return 1
}

# A Steam session counts as "running" if either the client UI is alive
# OR an installed game binary is executing. Game = keep paused.
steam_running() {
    if steam_client_running || game_running; then
        return 0
    fi
    return 1
}

# -------- actions ------------------------------------------------------
# A unit is either a user service or a system service (deterministic probe:
# if systemctl --user knows it, it's user-scoped, else system-scoped via sudo).
unit_scope() {
    local u=$1
    if [ -n "$(systemctl --user show -p FragmentPath --value "$u" 2>/dev/null)" ]; then
        echo user
    else
        echo system
    fi
}

is_unit_active() {
    local u=$1 scope; scope=$(unit_scope "$u")
    local st
    if [ "$scope" = user ]; then
        st=$(systemctl --user is-active "$u" 2>/dev/null)
    else
        st=$(sudo -n systemctl is-active "$u" 2>/dev/null)
    fi
    [ "$st" = "active" ]
}

stop_unit() {
    local u=$1 scope; scope=$(unit_scope "$u")
    if [ "$scope" = user ]; then
        systemctl --user stop "$u" 2>/dev/null
    else
        sudo -n systemctl stop "$u" 2>/dev/null
    fi
}

start_unit() {
    local u=$1 scope; scope=$(unit_scope "$u")
    if [ "$scope" = user ]; then
        systemctl --user reset-failed "$u" 2>/dev/null
        systemctl --user start "$u" 2>/dev/null
    else
        sudo -n systemctl reset-failed "$u" 2>/dev/null
        sudo -n systemctl start "$u" 2>/dev/null
    fi
}

pause_mining() {
    log "Steam detected - pausing mining + RAM daemons"
    for s in $MINER_SERVICES $AUX_SERVICES; do
        stop_unit "$s"
    done
    log "All miners + daemons paused"
}

# Start every miner that is not already active. Used on resume AND
# for self-healing when the watcher itself restarts.
# Returns: 0 = all units ok, 1 = at least one start command failed.
NEEDED_START=0
start_miners() {
    NEEDED_START=0
    local failed=0 s
    for s in $MINER_SERVICES $AUX_SERVICES; do
        if ! is_unit_active "$s"; then
            NEEDED_START=1
            if start_unit "$s"; then
                log "  [start] $s issued"
            else
                log "  [ERROR] $s failed to start"
                failed=1
            fi
        fi
    done
    return $failed
}

wait_all_active() {
    local deadline=$(( $(date +%s) + GRACE_ACTIVATE )) s
    while [ "$(date +%s)" -lt "$deadline" ]; do
        local all_active=1
        for s in $MINER_SERVICES $AUX_SERVICES; do
            if ! is_unit_active "$s"; then
                all_active=0
                break
            fi
        done
        if [ "$all_active" -eq 1 ]; then
            log "All miners + daemons active again"
            return 0
        fi
        sleep 5
    done
    for s in $MINER_SERVICES $AUX_SERVICES; do
        is_unit_active "$s" || log "  [WARN] $s not active"
    done
    log "Recovery window ended (some units may still be retrying)"
    return 1
}

resume_mining() {
    log "Steam exited - resuming ALL miners"
    if start_miners; then
        wait_all_active
    fi
}

ensure_miners_running() {
    # Watcher service restarted with Steam already closed: reconcile state.
    if start_miners; then
        if [ "$NEEDED_START" -eq 1 ]; then
            log "Startup reconcile: miner recovery issued"
            wait_all_active
        else
            log "Startup reconcile: all miners already active"
        fi
    fi
}

# -------- boot ---------------------------------------------------------
mkdir -p "$HOME/miners/logs"
log "steam-pause-watcher started (interval ${CHECK_INTERVAL}s)"
log "  libraries: ${STEAM_LIBRARIES[*]}"
log "  services:  $MINER_SERVICES + aux $AUX_SERVICES"

# First pass - sync immediately so miners never run under a live Steam,
# and are never left dead when Steam is already closed.
if steam_running; then
    LAST_STATE="running"
    log "Steam already running on startup - ensuring miners are paused"
    pause_mining
else
    LAST_STATE="idle"
    ensure_miners_running
fi

# -------- main loop ----------------------------------------------------
while true; do
    if steam_running; then
        if [ "$LAST_STATE" != "running" ]; then
            pause_mining
            LAST_STATE="running"
        fi
    else
        if [ "$LAST_STATE" = "running" ]; then
            resume_mining
        fi
        LAST_STATE="idle"
    fi
    sleep "$CHECK_INTERVAL"
done