# Changelog

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