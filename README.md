# Sword Tale: Lost Excalibur — Unofficial Bugfix & Linux Optimization

> **Community, unofficial.** Not affiliated with UTCC-DGS, ZDKHub, or Valve.
> Requires a legally owned copy of the game (it is free on Steam: App ID `3305630`).
> This repository contains **no game code and no game assets** — only original
> configuration, scripts, and documentation that operate *on top of* your existing
> installation.

## The short version

Sword Tale: Lost Excalibur is an **Unreal Engine 4.18.3** (Shipping) Windows game
with a documented, reproducible crash pattern: **the engine watchdog kills the game
~30 s into startup** (`GameThread timed out waiting for RenderThread after 30.00 secs`,
`RenderingThread.cpp:1015`). Multiple Steam reviews report repeated crashes inside
the first minute, on Windows hardware as well as Linux/Proton.

On Linux the stall is aggravated by first-boot shader pipeline compilation inside
DXVK, VR-runtime initialization (OpenVR/OpenXR) at process start, and the game's
texture-streaming default on 8 GB machines.

This repo packages the mitigations that are addressable **from outside the binary**,
plus a bug tracker you can paste back to the developer.

---

## Quick start (Linux / Steam)

### 1. Paste the launch options

Right-click the game → **Properties → Launch Options** and paste:

```
DXVK_FILTER_DEVICE_NAME="GeForce RTX 3050" DXVK_CONFIG="dxvk.numCompilerThreads=4,dxvk.maxFrameLatency=2,dxvk.enableGraphicsPipelineLibrary=True,dxvk.shrinkNvidiaHvvHeap=True" PROTON_ENABLE_NVAPI=1 gamemoderun %command% -nomovie -novsync -malloc=system
```

Adjust the device name to match your GPU (see `linux/launch-options.txt` for
alternatives and a minimal fallback variant).

**What each piece does** — see `docs/DIAGNOSIS.md` for the reasoning.

### 2. Install the optimized configs (optional but recommended)

```bash
cd linux/    # or config/
./install-configs.sh           # safely copies Engine.ini / Scalability.ini / GameUserSettings.ini templates into the Proton prefix
```

Backups are made automatically; `./revert-configs.sh` restores them.

### 3. Verify

```bash
tools/verify-launch.sh         # boots the game in its own prefix, reports PASS/FAIL
```

---

## Repo map

| Path | Purpose |
|------|---------|
| `linux/launch-options.txt` | Ready-to-paste Steam launch options (all variants) |
| `linux/swordtale-run.sh` | Standalone runner for non-Steam launchers (Lutris/Heroic/bare Proton) |
| `config/` | Optimized `Engine.ini`, `Scalability.ini`, `GameUserSettings.ini` templates + install/revert scripts |
| `tools/verify-launch.sh` | Automated launch smoke test (A/B your settings) |
| `tools/collect-crash-info.sh` | Bundle your crash evidence for bug reports |
| `tools/torch` | Steam-console bridge: live game-session watcher, console replay, system forensics, agent handoffs (`~/.torches/inbox/`) |
| `docs/DIAGNOSIS.md` | Full forensic write-up (engine, crash dump, DXVK behavior) |
| `docs/BUGTRACKER.md` | Catalogued community + verified issues with status and workarounds |

## Related

- [sword-tale-controller](https://github.com/intricos777-dot/sword-tale-controller) — controller/gamepad support configuration for the same game.

## License

MIT — the contents are original work of this repository's contributors.
See `LICENSE`.