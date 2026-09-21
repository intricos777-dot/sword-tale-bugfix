# Changelog

## [0.1.5] — 2026-09-21

### Resolved
- **ST-001d workaround confirmed**: Steam Offline mode lets the game reach
  checkpoints with zero crashes (every prior online session died silently).
  The .NET/network handshake at intro→gameplay feeds a misaligned buffer into
  the native SHA-1 path (RVA `0x60E63`) → undispatchable `0xc0000005`. Play
  offline until the developer patches it.

## [0.1.4] — 2026-09-21

### Added
- **ST-001d — root cause found**. Proton-log capture via `torch` revealed a native
  `0xc0000005` at RVA `0x60E63` (`movaps [rax-0x48]`, garbage `rax`) inside an Intel
  SHA-NI block of the mixed-mode (native + .NET) exe, right after `mscoree` /
  `NETAPI32` load at the intro→gameplay handoff. Exception undispatchable → no
  engine dump/log ever. This explains every "vanished corpse" run.
- `tools/torch`: live watch no longer overwrites the session slice with wrong
  line ranges; proton/wine log now folded into each session automatically.

## [0.1.3] — 2026-09-21

### Added
- `tools/torch` — Steam-console bridge: live watcher, session replay, system
  forensics, and seed handoffs into `~/.torches/inbox/` for agents (hermes /
  opencode). Ships with `torch-watch.service` (systemd user) and a torch pane in
  `steam-console-agents`.

### Changed
- `docs/BUGTRACKER.md` ST-001b: console evidence of **19.84 s frame gap at the
  intro→gameplay handoff** and repeated 8 s gaps before silent window death —
  render-thread knot at mission-load transition; 0-byte breakpad asserts in
  `/tmp/dumps` confirm a native assert that never materialized a dump.

## [0.1.2] — 2026-09-21

### Added
- `docs/BUGTRACKER.md` **ST-001c**: silent mid-game kills with **no engine crash
  artifact** — root cause is host RAM starvation triggering NVIDIA driver
  virtual-address-space failures (`NVRM: dmaAllocMapping_GM107: can't update VA
  space for mapping`, `virt_mem_allocator_gm107.c:2563`), not a game bug.
- `config/steam-pause-watcher-extended.sh`: hardened host-side memory guard that
  pauses RAM-hungry daemons (BCH node ~1.4 GB, ollama ~0.8 GB, miners) while Steam
  games run, and restarts them on exit. Requires `sudo -n` for system units.

### Changed
- `docs/BUGTRACKER.md` legend now includes `EXTERNAL (host)` fix scope.

## [0.1.1] — 2026-09-21

### Added
- `tools/verify-launch.sh` `STAY` mode: requires the game to survive N seconds
  after the engine log appears (validates mid-game liveness, not just boot).
- `docs/BUGTRACKER.md` ST-001b: gameplay-phase watchdog crashes (boots fine, dies
  while playing — shader-permutation compilation stalls) with cache-warming guidance.

### Changed
- `docs/DIAGNOSIS.md`: three-stage failure model; Steamworks IPC discovery
  (direct boots die calling `IClientUtils::SetAppIDForCurrentPipe` when Steam runs).

## [0.1.0] — 2026-09-21

Initial public release.

### Added
- `docs/DIAGNOSIS.md` — forensic analysis of the boot crash
  (`RenderingThread.cpp:1015` render-thread watchdog, UE 4.18.3) with local
  crash-dump evidence and Linux/Proton test matrix.
- `docs/BUGTRACKER.md` — community issue catalog (ST-001 … ST-032) with
  externality classification (EXTERNAL vs DEV).
- `linux/launch-options.txt` — five launch-option variants (recommended, minimal,
  FSR performance, wined3d fallback, Windows).
- `linux/apply-launch-options.sh` — prerequisite preflight + paste-ready string.
- `linux/swordtale-run.sh` — standalone Proton runner reusing the Steam prefix.
- `config/` — optimized `Engine.ini`, `Scalability.ini`, `GameUserSettings.ini`
  templates with install/revert scripts (backup-aware).
- `tools/verify-launch.sh` — automated boot smoke test (A/B your settings).
- `tools/collect-crash-info.sh` — one-command crash report bundle.
- GitHub Actions CI: shell syntax/shellcheck, Unreal .ini template validation,
  doc presence checks.

### Tested
- Crash artifact decoded (local prefix, 2026-09-18 session).
- DXVK/Proton behavior mapped across direct-run, Steam-launch, and mitigated
  configurations (see DIAGNOSIS §3).