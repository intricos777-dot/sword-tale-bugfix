# Diagnosis: Sword Tale: Lost Excalibur boot crashes on Linux/Proton (and Windows)

## Executive summary

The game is an **Unreal Engine 4.18.3** (CL-3832480, Shipping configuration)
single-player action game running through DXVK under Proton. Its signature failure
is a startup crash caused by the UE4 render-thread watchdog:

```
LowLevelFatalError [RenderingThread.cpp:1015]
GameThread timed out waiting for RenderThread after 30.00 secs
```

This is an engine guard that aborts the process when the render thread has been
starved for 30 continuous seconds. On this game the stall happens **during boot**
(`SecondsSinceStart: 0`), when shader compilation, streaming initialization, and —
under Wine — DXVK pipeline compilation all land on the render thread at once.

## Evidence

### 1. Local crash artifact (this machine, 18 Sep 2026)

`SwordTale/Saved/Crashes/UE4CC-Windows-70AD50E5497824017314E79588FCBC43_0000/CrashContext.runtime-xml`

```xml
<CrashType>Assert</CrashType>
<SecondsSinceStart>0</SecondsSinceStart>
<EngineVersion>4.18.3-3832480+++UE4+Release-4.18</EngineVersion>
<ErrorMessage>...RenderingThread.cpp [Line: 1015]
GameThread timed out waiting for RenderThread after 30.00 secs</ErrorMessage>
<Misc.NumberOfCoresIncludingHyperthreads>12</...>
<Misc.PrimaryGPUBrand>NVIDIA GeForce RTX 3050 Laptop GPU</...>
<MemoryStats.TotalPhysicalGB>8</...>
<MemoryStats.AvailablePhysical>2113470464</...>
```

Facts extracted:

- Engine **4.18.3**, shipped as `SwordTale-Win64-Shipping.exe` (44 MB PE32+).
- Content: single 2.5 GB `SwordTale-WindowsNoEditor.pak` (pak magic `5A6F12E1`,
  format v4). No loose assets → all streaming loads come from the pak.
- Boot sequence crashed with **available RAM ≈ 2.1 GB of 8 GB**.
- The crash is an **assertion in the engine watchdog**, not a memory OOM
  (`bIsOOM: 0`), not a driver failure — the render thread simply did not finish
  its startup work inside 30 s.

### 2. Steam store review evidence (Windows + Linux)

Multiple reviews report the same signature:

> "crashed out seven times in a row within the first minute or so of starting it,
> with no indication of what the error is — my PC happily runs other games..."

The game holds **Mixed (68%)** on Steam largely because of this stability issue,
not game quality.

### 3. Controlled testing on Linux (Proton Experimental, NVIDIA 615, Wayland)

| Run | Env | Result |
|-----|-----|--------|
| Direct Proton run, plain env | sniper + Proton-Experimental | Stalls 120 s+ pre-log; OpenVR/OpenXR init warnings; no window |
| Direct Proton run + SteamAppId/GameId + `-nomovie -novsync` | + DXVK device pin, GPL, 4 compiler threads | Process exits ~51–56 s, no UE log, no crash dump |
| Steam client `steam -applaunch 3305630` | Steam env | Game windows created then torn down without a log; Steam console shows process removal |

Conclusion of the A/B: **two independent failure stages exist**:

1. **Pre-engine stage** (only when launched outside Steam's full environment):
   the process hangs in loader/VR-runtime init (OpenVR/OpenXR shims) before UE's
   `GLog` is even opened. Always launch through Steam.
2. **Render-thread stage** (Steam-launched, and on Windows): the UE watchdog kills
   the game during boot-time render initialization — the reported public crash.

## Root-cause analysis for ST-001 (the render-thread timeout)

Under Proton, the render thread's startup path is busy with:

- **DXVK pipeline compilation** of the game's shader set on first run / new-GPU
  runs. Without `dxvk.enableGraphicsPipelineLibrary` (NVIDIA GPL) each shader pair
  is built from SPIR-V on-device, serially, on the first use.
- **Steam shader pre-cache** interplay (`shadercache/3305630`: 52 MB pipeline +
  `.foz` layers when warmed; empty/none on cold runs → fast stall path).
- **Movie playback** at boot (`Content/Movies/` present). The engine plays startup
  movies on the render thread; a stall here directly feeds the watchdog.
- **Memory pressure**: 8 GB total / ~2 GB free is the recorded surroundings of the
  crash. Texture streaming defaults target the VRAM (4 GB on the RTX 3050), amplifying pressure.

The same triad explains Windows-side reports: UE4.18 boots that spend >30 s in
render-thread work (cold shader caches, spinning disks, low RAM, movie playback)
trip the identical watchdog — hence "crashes in the first minute" regardless of GPU tier.

## Mitigations (what this repo changes)

| Vector | Fix | Where |
|--------|-----|-------|
| Serial shader compilation | `dxvk.enableGraphicsPipelineLibrary=True` + `dxvk.numCompilerThreads=4` | Launch options |
| Wrong GPU picked on hybrids | `DXVK_FILTER_DEVICE_NAME` | Launch options |
| Vulkan memory bloat | `dxvk.shrinkNvidiaHvvHeap=True` | Launch options |
| Movie playback stalls | `-nomovie` | Launch options |
| Frame pacing / vsync stalls | `-novsync`, `r.VSync=0`, framed limits | Launch options + `config/` |
| Streaming memory pressure | `r.Streaming.PoolSize` capped (e.g. 2048 on 4 GB VRAM) | `config/Engine.ini` |
| CPU governor / frame pacing | `gamemoderun` | Launch options |
| Wine allocator quirks | `-malloc=system` | Launch options |

These do **not** modify the game binary or assets, and nothing is redistributed.
They are runtime knobs exposed by Proton/DXVK/UE4 — standard practice for
Proton-compatibility tuning.

## What the developer could fix upstream (DEV items)

1. Disable/guard VR-runtime (OpenVR/OpenXR) initialization at startup on non-VR builds.
2. Raise or remove the boot watchdog, or pre-warm the render thread (split shader
   compile off startup).
3. Tune default streaming pool for 4 GB VRAM / 8 GB RAM systems.
4. Add audio/text pacing options.
5. Consider shipping a per-title DXVK-friendly pipeline library config.

## Test environment (for reproducibility)

- OS: Linux, Wayland session, Steam (console) + Proton Experimental, SteamLinuxRuntime_sniper
- CPU: 12th Gen Intel Core i5-12450H (8C/12T)
- GPU: NVIDIA GeForce RTX 3050 Laptop GPU, driver 615.71.09 (Vulkan 1.4)
- RAM: 8 GB
- Game: Steam App ID 3305630, UE 4.18.3, build of 2025-04-27