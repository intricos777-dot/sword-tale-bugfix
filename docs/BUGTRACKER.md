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
| Fix | `EXTERNAL` — addressable from outside the game binary (this repo helps), `EXTERNAL (host)` — host-machine environment fix (RAM/CPU headroom, drivers), `DEV` — requires a developer/engine patch, `DESIGN` — intended behavior dispute |

## Crash / stability

| ID | Issue | Evidence | Sev | Fix | Status / Workaround |
|----|-------|----------|-----|-----|---------------------|
| ST-001 | **`GameThread timed out waiting for RenderThread after 30.00 secs`** during startup (UE `RenderingThread.cpp:1015` assert, `SecondsSinceStart: 0`) | Local crash dump `UE4CC-Windows-70AD50E5…` (WindowsNoEditor/Shipping, UE 4.18.3 CL-3832480, NVIDIA RTX 3050, 8 GB RAM); Steam reviews reporting repeated first-minute crashes on Windows | BLK | EXTERNAL + DEV | Reduce boot-time render-thread stalls: DXVK pipeline library + extra compiler threads + GPU pinning + `-nomovie` (see `linux/launch-options.txt`). Developer should verify under 8 GB systems and strip VR-runtime init from boot. |
| ST-001b | **Watchdog-style death mid-game on well-provisioned systems**: the game boots, the intro passes, gameplay begins — then the crash lands while playing (usually on first encounter with a new area's material/shaders) | User report (local, 2026-09-21): "crashes after I can actually move past the intro"; Steam console (16:37 run): **19.84 s frame gap at the intro→gameplay handoff**, repeated 8 s gaps, then silent window death (`Window title set to (empty)`); 0-byte breakpad `assert_*.dmp` in `/tmp/dumps` | BLK | EXTERNAL + DEV | Hypothesis: render thread stalls on **on-the-fly shader permutation compilation** for each new level/material. Warm the caches: `dxvk.enableGraphicsPipelineLibrary=True` + `dxvk.numCompilerThreads` + Steam shader pre-cache. First 1–2 full sessions build the DXVK state cache (`shadercache/3305630/DXVK_state_cache`). **Note:** on low-RAM hosts (this one included), observed mid-game deaths were NOT the watchdog but host RAM starvation (ST-001c) — no `UE4CC-*` dump was written. Capture runs with `tools/torch` + the `-abslog` launch options are required to obtain the engine's own death note. |
| ST-001c | **Mid-gamekill with no engine crash artifact** — the process dies silently while playing and no `UE4CC-*` dump is written | Kernel log (2026-09-21): repeated `NVRM: dmaAllocMapping_GM107: can't update VA space for mapping` + `nvCheckFailedNoLog … virt_mem_allocator_gm107.c:2563` at 16:24/16:28/16:29, mirroring game process exits; system memory at 154 MiB free / 7.8 GiB swap in use | BLK | EXTERNAL (host) | On low-RAM hosts the **GPU driver's virtual-address allocator fails under physical-memory starvation**, killing the game driver-side before UE4 can assert. Host-side fix: keep ≥ 3 GiB RAM free during play — pause RAM-hungry daemons (node/miners/LLM: see `config/steam-pause-watcher-extended.sh`), cap streaming pool (`config/Engine.ini`), ensure swap exists. Not a game bug; no engine patch needed. |
| ST-001d | **Native access violation in the game exe when entering gameplay** — silent death; the true "vanish-every-body" bug | Proton log (2026-09-21, capture run): `Exception 0xc0000005 (EXCEPTION_ACCESS_VIOLATION) addr=0000000140060E63`, info\[0\]=0 / info\[1\]=FFFFFFFFFFFFFFFF (read of an invalid pointer); `err:seh: … Exception frame is not in stack limits => unable to dispatch exception`; disassembly shows `movaps xmm6, [rax-0x48]` inside an **Intel SHA-NI routine** (sha1msg1/rnds4/nexte/msg2 block) with a garbage `rax`; the exe carries a **CLR runtime header** and loads `mscoree` (434 references) + `NETAPI32.dll` immediately before the fault | BLK | DEV | The game is a **mixed-mode (native + .NET) binary**: its managed component drives a network/telemetry handshake at the intro→gameplay transition whose native SHA-1 hashing reads a freed/misaligned buffer. Engine never sees it (exception undispatchable → no dump, no log) — explains ST-001/ST-001b observations where NO artifacts appeared. Workarounds to test: **Steam Offline mode** (skips the network handshake) and **Proton 11 vs Experimental** (different `mscoree`/CLR host). Real fix is dev-side: correct the buffer lifetime/alignment in the SHA-1 call path (reproduce at RVA `0x60E63`). |
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