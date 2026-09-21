# Sword Tale: Lost Excalibur — Bug Tracker

> Community tracker for issues affecting **Sword Tale: Lost Excalibur**
> (Steam App ID `3305630`, developer UTCC-DGS). Everything here is compiled from
> public sources (Steam reviews, discussions), local crash artifacts, and
> controlled testing on Linux/Proton. **This is a community document — it is not the
> official developer tracker.** Feel free to open GitHub issues or paste entries
> back to the developer via the [Steam discussions forum](https://steamcommunity.com/app/3305630/discussions/).

## Legend

| Column | Meaning |
|--------|---------|
| ID | tracker ID used in this repo |
| Sev | severity: `BLK` blocking, `MAJ` major, `MIN` minor, `NIT` nitpick |
| Fix | `EXTERNAL` — addressable from outside the game binary (this repo helps), `DEV` — requires a developer/engine patch, `DESIGN` — intended behavior dispute |

## Crash / stability

| ID | Issue | Evidence | Sev | Fix | Status / Workaround |
|----|-------|----------|-----|-----|---------------------|
| ST-001 | **`GameThread timed out waiting for RenderThread after 30.00 secs`** during startup (UE `RenderingThread.cpp:1015` assert, `SecondsSinceStart: 0`) | Local crash dump `UE4CC-Windows-70AD50E5…` (WindowsNoEditor/Shipping, UE 4.18.3 CL-3832480, NVIDIA RTX 3050, 8 GB RAM); Steam reviews reporting repeated first-minute crashes on Windows | BLK | EXTERNAL + DEV | Reduce boot-time render-thread stalls: DXVK pipeline library + extra compiler threads + GPU pinning + `-nomovie` (see `linux/launch-options.txt`). Developer should verify under 8 GB systems and strip VR-runtime init from boot. |
| ST-001b | **Same watchdog, but mid-game**: the game boots, the intro passes, gameplay begins — then the crash lands while playing (usually on first encounter with a new area's material/shaders) | User report (local, 2026-09-21): "crashes after I can actually move past the intro" | BLK | EXTERNAL + DEV | During gameplay the render thread stalls on **on-the-fly shader permutation compilation** for each new level/material. Warm the caches: `dxvk.enableGraphicsPipelineLibrary=True` + `dxvk.numCompilerThreads` + Steam shader pre-cache. First 1–2 full sessions build the DXVK state cache (`shadercache/3305630/DXVK_state_cache`) — the game progressively stabilizes. Verify with `STAY=300 tools/verify-launch.sh`. |
| ST-002 | Crashes / hangs **before** the engine loop when launched outside Steam's full environment | Reproduced: direct Proton launches stall 50–120 s at OpenVR/OpenXR init with no `SwordTale.log` produced | BLK | EXTERNAL | Always launch through the Steam client; `swordtale-run.sh` is a fallback only. |
| ST-003 | No `SwordTale.log` written on early failure | Verified in prefix `.../AppData/Local/SwordTale/Saved/Logs/` stays empty when boot stalls | MIN | DEV | Developer: ensure `GLog` opens earlier / add startup log capture. |

## Performance

| ID | Issue | Evidence | Sev | Fix | Status / Workaround |
|----|-------|----------|-----|-----|---------------------|
| ST-010 | Severe FPS drops; reports of ~30 FPS on high-end GPUs | Steam reviews (`RTX 5070 Ti ~30 FPS`), performance complaints | MAJ | EXTERNAL + DEV | Apply `config/` templates (streaming pool cap, sync off). Generic UE4.18 profile issues also need developer attention. |
| ST-011 | Long startup / stutter bursts at load | Local testing: minutes-level stall under memory pressure (8 GB RAM, ~2 GB free) | MAJ | EXTERNAL | Warm Steam shader pre-cache, DXVK GPL, `dxvk.numCompilerThreads`, capped `r.Streaming.PoolSize`. |
| ST-012 | Hybrid-GPU laptops may enumerate the wrong Vulkan device first | Analysis of local hybrid (Intel + NVIDIA) system | MIN | EXTERNAL | `DXVK_FILTER_DEVICE_NAME` / `VKD3D_FILTER_DEVICE_NAME`. |

## Input / gameplay

| ID | Issue | Evidence | Sev | Fix | Status / Workaround |
|----|-------|----------|-----|-----|---------------------|
| ST-020 | No controller support (keyboard/mouse only per store page) | Reviews | MAJ | DEV | See companion repo `sword-tale-controller` (Steam Input + `Input.ini`). |
| ST-021 | Blocking only absorbs the first hit of a combo | Reviews | MIN | DESIGN/DEV | Developer design call. |
| ST-022 | Broken weapon doesn't auto-draw replacement | Reviews | MIN | DEV | Developer patch. |
| ST-023 | Combat stiffness / unreadable enemy tells | Reviews | MIN | DESIGN | Developer design call. |

## Content / localization

| ID | Issue | Evidence | Sev | Fix | Status / Workaround |
|----|-------|----------|-----|-----|---------------------|
| ST-030 | Dialogues auto-advance too fast for some readers; no voiceover | Reviews | MIN | DEV | Developer patch (add text pacing/options). |
| ST-031 | Rough translation / grammatical errors | Multiple reviews | NIT | DEV | Crowd-sourced localization pass — offer PRs if the developer opens assets. |
| ST-032 | No achievements | Reviews | NIT | DEV | Developer feature. |

## How to contribute

1. Open an issue here with reproduction steps + log/crash evidence (use `tools/collect-crash-info.sh`).
2. If you have a fix for any tracked issue, open a PR. All contributions must be original work.
3. Respectful reports to the developer are encouraged — it is a student-team project
   (University of the Thai Chamber of Commerce, Digital Game Simulation program).