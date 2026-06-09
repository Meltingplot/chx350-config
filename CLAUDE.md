# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MeltingPlot CHX350 3D printer configuration repository. Contains machine configuration, calibration macros, filament profiles, and safety/automation scripts for a professional multi-axis 3D printer running Duet 3 firmware (RepRapFirmware 3.6.1).

**Language:** Duet G-code (not traditional programming — machine control scripts executed by firmware).

**No build/test/lint system.** Scripts are loaded directly by the Duet firmware at startup (`sys/config.g`) or invoked via the Duet web interface / G-code console. Validation is done manually on hardware.

## Architecture

### Boot Sequence

`sys/config.g` is the entry point — executed by firmware on startup. It:
1. Loads global variables (`sys/meltingplot/globals`)
2. Configures hardware (motors, heaters, fans, sensors, probes)
3. Loads CE compliance settings and machine-specific overrides
4. Restores saved parameters from non-volatile memory (`M501`)

### Print Flow

`start.g` → `print_start` (door checks → homing → bed leveling → nozzle clean → prime) → print → `stop.g` → `print_end` (cleanup, safety reset)

### Key Directories

- **`sys/`** — System config, firmware hooks (`start.g`, `stop.g`, `pause.g`, `resume.g`, `homeall.g`, etc.), and the `meltingplot/` subsystem
- **`sys/meltingplot/`** — Core logic: global state, safety checks, print start/end, filament loading, LED control, nozzle cleaning, z-probe modes, CE compliance
- **`filaments/`** — 29 material profiles, each with `config.g` (parameters), `load.g`, and `unload.g`
- **`macros/meltingplot/`** — User-callable calibration and maintenance macros

### State Management

Global state is centralized in `sys/meltingplot/globals`. Key variables:
- `global.result` — error propagation between macros (0 = success)
- `global.potential_unsafe_state` — blocks operations when unsafe
- `global.machine_mode` — operating mode ("default" or "automatic")
- `global.door_left_open` / `global.door_right_open` — door interlock state
- `global.debug` — enables debug echo messages

### Background Monitoring

`sys/daemon.g` runs continuously, monitoring door states, stall events, temperatures, and LED status.

### Hardware Topology

- **Kinematics:** CoreIDXY (K5) with dual Z-axis (X, Y, Z, U axes)
- **CAN bus boards:** Expansion 1HCL at addresses 50 (X1), 51 (X2), 52 (Y), 53 (U); toolboard at 20; accelerometer at 60
- **Sensors:** Scanning Z-probe (LDC1612 inductive), filament monitor (MFM), PT1000 hotend, thermistor bed
- **Build volume:** 880 x 422 x 950 mm

## Duet G-code Reference

Official docs: https://docs.duet3d.com/en/User_manual/Reference/Gcodes and https://docs.duet3d.com/User_manual/Reference/Gcode_meta_commands — always consult these rather than guessing about RRF G-code behavior.

### Meta Code Programming
RRF extends standard G-code with meta commands that provide programming capabilities. Supported constructs: `var`/`global`/`set` for variable declaration and assignment, `if`/`elif`/`else` for conditionals, `while` for loops (with `break` and `continue`), `echo` for output (including file redirection with `>`, `>>`, `>>>`), and `abort` to terminate all nested macros and the current print. Block structure is **indentation-based** — the body of `if`, `elif`, `else`, and `while` must be indented from the keyword, and the block ends at the first non-indented line. Available types are bool, int, float, string, DateTime, object, and array. Expressions support arithmetic, comparison, boolean (`&`/`|`/`!`), string concatenation (`^`), length (`#`), and ternary (`? :`). Built-in functions include `abs`, `ceil`, `cos`, `exists`, `fileexists`, `fileread`, `find`, `floor`, `max`, `min`, `mod`, `random`, `round`, `sin`, `sqrt`, `vector`, among others. Note: `*` (multiply) only works inside `{ }` expressions since `*` normally introduces a checksum in G-code.

### Input Channels
RRF processes G-code from multiple independent input channels: USB, HTTP (DWC), PanelDue/UART, Telnet, SD card (file), second UART, MQTT Client, and second USB. Each channel maintains **its own independent state** for: feed rate, arc plane (G17/G18/G19), units (G20/G21), absolute/relative positioning (G90/G91), feed rate mode (G93/G94), extruder abs/rel (M82/M83), and volumetric extrusion (M200). At the end of `config.g`, these states are copied to all channels. When a macro runs, the channel state is saved and restored on return — but changes made during job files persist for the session.

The channel distinction matters for:
- **Command queueing:** Deferred queueing of certain non-movement commands (M106, M104, M568, etc.) only applies to the File channel (job files), not commands sent interactively via HTTP/USB.
- **`echo` output:** `echo` only sends output back to the input channel it was called from. To send messages to a specific target (DWC, USB, PanelDue, MQTT), use `M118` with the P parameter (P0=generic/all, P1=USB, P2=PanelDue, P3=HTTP, P4=Telnet, P5=second UART, P6=MQTT, P7=second USB).
- **Channel blocking:** A blocking command (e.g., M109, M190) on one channel blocks only that channel. To cancel, M108 must be sent from a different, unblocked channel.
- **Triggers:** Trigger macros (sys/trigger#.g) execute without waiting for queued moves to complete — use `M400` at the start of trigger macros if synchronization is needed.

### Command Queueing and Execution Order
RRF maintains a **move queue** (look-ahead buffer) for G0/G1/G2/G3 movement commands, and a **deferred command queue** for certain non-movement commands. Together these operate as a single logical queue. Commands from job files and macros are queued — meaning they are acknowledged immediately when placed in the queue, not when executed. This has important implications:

- **Always queued:** G0, G1, G2, G3 moves (except homing/probing moves which are special).
- **Queued when from a file** (and parameters contain no `{ }` expressions): M3, M4, M5 (non-laser), M42, M104, M106, M107, M117, M140, M141, M144, M280, M300, M568, and G10 (without L, with at least one P/R/S/axis parameter).
- **Wait for movement to stop:** Configuration commands (M93, M906, M201, M569, etc.), probing commands, G4, M400, and T commands. These drain the queue before executing.
- **Never queued:** Meta commands (`echo`, `if`, `set`, etc.) execute immediately and do not interact with the queue.
- **Forcing synchronization:** `M400` waits for all queued moves to complete (clears the queue). Use it when subsequent commands depend on motion being finished — e.g. before reading positions, checking sensors, or evaluating conditions that depend on physical state.
- **Bypassing the queue:** If a normally-queued command contains a parameter with an Object Model expression in `{ }`, it is **not** queued because the expression value may change and cannot be evaluated in queue context.

### File Inclusion (M98)
`M98 P"filename"` runs a macro. Relative paths default to `/sys`. Absolute paths use `0:/` (SD card root). Parameters are passed as additional G-code letters: `M98 P"macro.g" S100 Y"string"`. Inside the macro, access via `param.S`, `param.Y` (single uppercase letter). P and R are reserved. Use `exists(param.S)` to check if provided. A command invoking a macro must be the last command on its line.

### M99: Early Return from Macro
`M99` returns from the current macro early. Not required at end of file — macros naturally return at EOF.

### Variables
- **Global:** `global <name> = <expr>` to declare, `set global.<name> = <expr>` to assign. Persists across macros.
- **Local:** `var <name> = <expr>` to declare, `set var.<name> = <expr>` to assign. Scoped to the current block.
- **Parameters:** `param.<letter>` — single uppercase letter, from M98 call.

### Named Constants
- `result` — firmware built-in: 0=success, 1=warning, 2+=error, -1=M291 cancelled/timed out. Set after each G/M/T command. Meta commands do not change `result`.
- `iterations` — completed loop iterations (0-based) for innermost `while` loop.
- `input` — most recent M291 message box input (modes 4-7).
- `line` — current line number in executing file.

### Error Handling
Two distinct mechanisms are used in this codebase:

**Firmware `result`** — check after G/M commands:
```gcode
G32
if result != 0
  echo "Error: bed leveling failed"
  abort
```

**Project `global.result`** — cross-macro error propagation:
```gcode
set global.result = 0
M98 P"0:/sys/meltingplot/check_doors_closed"
if global.result != 0
  echo "Error: doors not closed"
  M99
```

### Loop Safety
`while` loops should include an `iterations` guard to prevent infinite loops (no way to break out except machine reset):
```gcode
while condition
  if iterations > 200
    echo "Error: timeout"
    break
```

### Expressions
Use `{ }` for expressions inside G-code commands: `G1 X{move.axes[0].max - 10}`. The `^` operator concatenates strings. The `#` operator gives array/string length.

### daemon.g
`sys/daemon.g` is executed repeatedly by the firmware as a background loop. It should contain a `while true` loop to avoid reopening the file every 10 seconds.

### Comment Style
Scripts start with a brief description comment. Inline comments explain hardware-specific M/G-code parameters. From RRF 3.6.0, comment indentation is no longer significant.

### Filament Loading and DWC Interaction
The RRF filament system predates meta G-code, creating timing constraints. Key issue: `move.extruders[n].filament` in the Object Model is NOT updated until `load.g` completes, so `load.g` cannot query its own filament name.

**DWC filament load sequence:** `T0` (tpre0→tpost0→M703, but no filament name yet) → `M701 S"name"` (load.g runs, OM updates after) → `M703` (config.g runs, OM is now correct). Only the final `M703` → `config.g` has the correct filament identity.

**Deferred loading pattern:** `load.g` sets temperatures and `global.deferred_filament_load_t0 = true`, then exits without physically loading. The centralized `sys/meltingplot/load_filament_sensorless_conditionally.g` checks this flag and calls `load_filament_sensorless` when set. Each filament's `config.g` calls this file via `M98 P"0:/sys/meltingplot/load_filament_sensorless_conditionally.g"`.

### MFM (Rotating Magnet Filament Monitor) — Firmware Semantics
Verified against RRF source (`RotatingMagnetFilamentMonitor.cpp`, `Duet3DFilamentMonitor.cpp`). Config here: `M591 P3 D0 R60:180 E5 L25.3` (tolerance 60–180 %, 5 mm check segment, 25.3 mm/rev sensitivity).

**Ratio / pause trigger is per-segment, NOT cumulative.** Each ~`E`-mm segment computes `lastMovementRatio = (measuredRevs / commandedMm) * mmPerRev`, i.e. `real filament / commanded filament`. `commandedMm` is derived from **e-steps** (`steps / e-steps`). Pause: `lastMovementRatio < R-min` → P=4 (tooLittleMovement), `> R-max` → P=5 (tooMuchMovement). So a wrong e-steps value is a **constant** ratio offset (`e_steps_configured / e_steps_real`), it does **not** mathematically integrate.

**Why long prints false-pause anyway (e-steps error class):** a constant bias parks the baseline closer to the `R`-min/max wall, so normal per-segment measurement noise (slip, backlash, retracts) crosses the threshold eventually — probability of ≥1 false trip → 1 as segment count grows. Statistically inevitable over time, not integration. The transient handlers (swing/oscillation suppression, auto-recovery) do NOT address this systematic class — recovery either falsely "confirms" (reading still biased >50 % → resume → re-trips → loop) or falsely "fails" (biased <50 % → stays paused though filament is fine).

**Remote (CAN/toolboard) computation — verified against `Duet3Expansion/.../RotatingMagnetFilamentMonitor.cpp` (3.6.3-rc.1):** our MFM is on the toolboard (CAN addr 20), so `Check`/`CheckFilament` run **on the toolboard**. The toolboard maintains and **integrates over the whole print** `totalExtrusionCommanded` and `totalMovementMeasured` (accumulated every comparison in the `comparing` state, never reset mid-print). From those it derives `MeasuredSensitivity = totalExtrusionCommanded/totalMovementMeasured` (= `calibrated.mmPerRev`) and `avgPercentage = totalMovementMeasured*mmPerRev/totalExtrusionCommanded*100`, and ships a subset back via `FilamentMonitorDataNew2`→`UpdateLiveData`. **This is where a systematic e-steps/sensitivity error integrates** — every comparison biases in the same direction, so `avgPercentage`/`calibrated.mmPerRev` converge tightly on the bias factor as the print grows.

**Pause trigger is still per-segment, not the integral.** P=4/P=5 fire on `lastMovementRatio = (amountMeasured/amountCommanded) * mmPerRev` per ~`E`-mm segment using the **configured** `L` (NOT `MeasuredSensitivity`). So `calibrated.mmPerRev` is an *output* of the integrating totals, not fed back into the decision. The "inevitable pause on long prints" is the per-segment value on a bias-shifted baseline + measurement noise eventually crossing `R-min`/`R-max` — same root cause as the integral, visible in two places.

**Which OM fields exist remotely:** the whole **`calibrated.*` subtree is gated on `IsLocal()`** (RRF main-board OM table) → **NOT exposed in the main-board OM for remote monitors** (the toolboard still *computes* it internally, it's just not surfaced as `sensors.filamentMonitors[0].calibrated`). Remote-safe OM fields (gated only on `hasLiveData`, populated from the CAN message): `avgPercentage`, `lastPercentage`, `minPercentage`, `maxPercentage`, `position`, `totalExtrusion`. `configured.*` (your `L`/`R`/`E`) lives on the main board, always available.

**Detection signal (remote-safe):** use `avgPercentage` — it equals `mmPerRev/MeasuredSensitivity*100`, i.e. **`avgPercentage` IS the integrated bias factor in percent**, and it's the CAN-transported view of the same integral that backs the (locally-only) `calibrated.mmPerRev`. Systematic bias = `avgPercentage` settling stably away from 100 % once `totalExtrusion` is large enough for the whole-print mean to converge, with a **narrow** `maxPercentage − minPercentage` spread. A real jam looks opposite: sudden drop, high variance, worsening, recovery test fails. Caveat: `min`/`maxPercentage` are **all-time running extremes, never reset mid-print** (post-jam the min stays low forever) — they corroborate early-print stability but are not a live variance measure.

**Fundamental ambiguity:** the MFM **cannot** distinguish a wrong e-steps from a wrong `L` (sensitivity) — both are the same measurement (commanded-mm vs measured-revs×L mismatch), and both look like genuine constant under-/over-extrusion. Therefore **never silently auto-compensate** (e.g. pulling `L` to `calibrated.mmPerRev`): that masks a real e-steps fault and prints dimensionally wrong parts while the MFM reports 100 %. Detect → **warn the operator** to recalibrate; only re-center adaptively (to save an in-progress print) alongside a persistent warning.

**`avgPercentage` is a whole-print integral, restarts only on pause/stop.** The toolboard's `totalExtrusionCommanded`/`totalMovementMeasured` are only ever `+=` in `CheckFilament`; they restart when the monitor goes `idle` via `Clear()`→`Reset()` (= not printing, i.e. pause/stop), never mid-print, and `M92` does not touch the monitor. So after an e-steps correction `avgPercentage` does **not** return to 100 % within the same print (historical biased extrusion stays in the mean) — do not use it as a success criterion. The per-segment `lastPercentage` (the actual P=4/P=5 trigger) normalises right after the correction; that's what matters.

**Implemented flow-bias detector (`daemon.g`):** one-shot per print, triggered by a **time-sustained, settled drift — not a fixed distance** (a distance trigger reliably lands in an awkward section, e.g. many short moves the MFM reads poorly; the whole-print integral is instead intrinsically robust to momentary sections). Sampling every 60 s: if `avgPercentage` is inside the ±3 % deadband the window clears; if it leaves the deadband a settle window opens, and any subsequent move >3 % from the window's reference restarts it (this filters a *progressing* fault — a developing clog should pause, not be compensated). Only when avg stays outside the deadband **and** flat for the full window (`mfm_esteps_drift` sustain = 600 s) does it capture the configured e-steps as `global.mfm_esteps_baseline`, compute `baseline*100/avgPercentage`, clamp to `[baseline*0.95, baseline*1.05]`, apply via `M92`, and pop a persistent `M291` (stronger wording when the needed correction exceeds the ±5 % clamp). The clamp is **absolute vs the baseline, not the last applied value** — no ratcheting across prints. `print_end` restores `M92 E{baseline}` so the bounded correction never silently leaks into the next print; each print re-derives and re-warns. Caveat: `M92` mid-print drains the move queue once (brief motion sync).

### Auto-Generated Calibration Files
Calibration macros generate config files in filament directories (e.g., `config-auto-esteps.g`, `config-auto-nle.g`). These should not be hand-edited.
