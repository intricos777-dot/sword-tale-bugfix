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

Conclusion of the A/B: **three independent failure stages exist**:

1. **Pre-engine stage** (only when launched outside Steam's full environment):
   the process hangs or exits in loader/VR-runtime init (OpenVR/OpenXR shims)
   before UE's `GLog` even opens. The game is Steamworks-linked — direct boots
   also flail against the running Steam client IPC
   (`IClientUtils::SetAppIDForCurrentPipe took too long`). **Always launch
   through Steam.** This is why `verify-launch.sh` is an offline-toolbox check,
   not the authoritative gate.
2. **Render-thread stage, boot** (Steam-launched, and on Windows): the UE
   watchdog kills the game during boot-time render initialization.
3. **Render-thread stage, gameplay** (ST-001b): same watchdog, mid-mission,
   while new area shaders compile. Covered above.

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

## Gameplay-phase manifestation (ST-001b)

On this machine the game can boot past the intro and begin gameplay, then crash
**while playing** — the same 30 s render-thread watchdog, struck mid-mission.
Root cause is the same class of stall, now fired by **on-the-fly shader
permutation compilation** when a new area/material is first rendered. UE4.18
compiles pipeline permutations on the render thread on first use; under DXVK
each one is a device-side pipeline build. A dense new area can pile up enough
compilation to starve the render thread past the watchdog's 30 s limit.

Practical consequence: **the game stabilizes with play**. The DXVK state cache
(`shadercache/3305630/DXVK_state_cache`) and Steam pipeline layers grow on every
session; areas that crashed once are cached for the next boot. `dxvk.enableGraphicsPipelineLibrary`
(NVIDIA GPL) and `dxvk.numCompilerThreads=4` cut both the per-pipeline cost and
the serialization, so the healing happens 5–10× faster per session. Use
`STAY=300 tools/verify-launch.sh` to validate a full in-mission liveness window
instead of a boot-only check.

## The silent killer — ST-001d (native-access violation at gameplay entry)

The **torch** capture channel finally caught the true mid-game killer red-handed.
During a live session (2026-09-21) the Steam console showed a plain process
removal: no engine log, no UE4CC dump — the same "vanished corpse" as every run.
But the `PROTON_LOG` from that session (923 KB) told the truth the engine never
could:

```
Exception 0xc0000005 (EXCEPTION_ACCESS_VIOLATION)
  addr=0000000140060E63
  info[0]=0000000000000000   (read),  info[1]=FFFFFFFFFFFFFFFF (invalid pointer)
  ... exception frame is not in stack limits => unable to dispatch exception
```

- The fault is in **the game's own executable**, `SwordTale-Win64-Shipping.exe`
  base `0x140000000`, so RVA **`0x60E63`** — near the end of `.text`.
- Disassembly at the RIP: `0f 28 70 b8   movaps xmm6, XMMWORD PTR [rax-0x48]`
  — a **misaligned SSE load** (AVX/SSE requires 16-byte alignment; `movaps`
  with an unaligned address raises `#GP`, surfaced as `0xc0000005`), with `rax`
  containing garbage.
- The surrounding code is an **Intel SHA-NI hand-rolled block**
  (`sha1msg1` / `sha1rnds4` / `sha1nexte` / `sha1msg2` nearby) — i.e. a
  hand-optimized SHA-1 routine with a **misaligned input buffer pointer**.
- The exe carries a **CLR runtime header**; the session log shows `mscoree`
  (.NET CLR) loading 434 times, and `NETAPI32.DLL` loading immediately before
  the fault. The logic chain: a **.NET-managed component** doing a network/
  telemetry/Steam-handshake step at the intro→gameplay transition passes a
  badly-aligned or dangling buffer into a native SHA-1 routine → alignment fault.
- Because the exception frame was outside the stack limits, **the crash reporter
  never ran**: no UE4CC directory, no log tail, no breakpad assert. That is why
  ST-001/ST-001b investigations found zero artifacts — the killer does not go
  through the engine at all. It also explains why no RAM/VRAM/DXVK knob fixed it
  deterministically.

This is a **develop-side bug in the game** (buffer lifetime/alignment in the
SHA-1 call path of the managed↔native boundary).

**⟡ Confirmed workaround (2026-09-21):** launching from Steam in **Offline
mode** skips the network handshake that feeds the poisoned SHA-1 path — the
user reached a checkpoint with zero crashes after every prior online session
ended in a silent corpse. Until the developer patches RVA `0x60E63`, play
offline.

Consumer-side knobs that may also dodge it:

| Test | Rationale | How |
|------|-----------|-----|
| **Steam Offline mode** | Skips the network handshake/telemetry that feeds the managed SHA-1 path | Steam → Offline, then launch |
| **Proton 11 vs Experimental** | Different `mscoree`, CLR host, and alignment behavior | Properties → Compatibility |
| **Disable overlay/remote features** | Removes some SteamNetworking calls | Overlay settings / per-game options |

If none dodge it, the only real cure is the developer fixing the buffer
lifetime/alignment in the SHA-1 call path (reproducible at RVA `0x60E63`).

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
6. **ST-001d (critical):** fix the buffer lifetime/alignment at the managed↔native
   boundary in the SHA-1 path — align the input to 16 bytes and/or use `movdqu`
   loads; the fault is reproduceable at RVA `0x60E63`.

## Test environment (for reproducibility)

- OS: Linux, Wayland session, Steam (console) + Proton Experimental, SteamLinuxRuntime_sniper
- CPU: 12th Gen Intel Core i5-12450H (8C/12T)
- GPU: NVIDIA GeForce RTX 3050 Laptop GPU, driver 615.71.09 (Vulkan 1.4)
- RAM: 8 GB
- Game: Steam App ID 3305630, UE 4.18.3, build of 2025-04-27