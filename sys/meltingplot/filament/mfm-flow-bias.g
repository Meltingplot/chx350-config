; filament/mfm-flow-bias.g
; Systematic flow-bias (e-steps) detection - WARN ONLY, never apply here. Called by
; trigger8.g every 60 s while printing (the print tick it shares with the spool booking).
; avgPercentage is the toolboard's whole-print integral (only restarts when the monitor goes
; idle on pause/stop), so it is robust to a momentary awkward section (many short moves the MFM
; reads poorly). Act only on a SETTLED, time-sustained drift, NOT at a fixed distance: avg must
; stay outside the ±3% deadband AND flat (within ±3% of the window reference) for the whole
; sustain window; any move >3% restarts the window (filters a progressing fault), any in-deadband
; sample clears it. One warning per print. NOTE: the correction MUST NOT be applied here - M92
; calls LockAllMovementSystemsAndWaitForStandstill and would hold the Trigger channel (and
; trigger4.g's door downgrade behind it) until motion stops. filament-error.g applies it at
; standstill on the next MFM error; the operator recalibrates via the e-steps macro.
; state.status "processing" is also true for macros, so the job is checked here.
if global.mfm_esteps_detected || job.file.fileName == null
  M99
; cache avg for atomicity — used in the gate, the math, and the message
var avg = sensors.filamentMonitors[0].avgPercentage
; a reduced speed (M220 below 100 %) depresses the reading — that avg is not a valid flow-bias
; sample, so clear the drift window and only accumulate drift at full speed.
if var.avg == null || move.speedFactor < 1 || (var.avg >= 97 && var.avg <= 103)
  set global.mfm_esteps_drift_since = 0
elif global.mfm_esteps_drift_since == 0 || abs(var.avg - global.mfm_esteps_drift_avg) > 3
  ; (re)start the settle window: drift just began, or avg is still moving (not settled)
  set global.mfm_esteps_drift_since = state.upTime
  set global.mfm_esteps_drift_avg = var.avg
elif (state.upTime - global.mfm_esteps_drift_since) >= 600
  ; avg has been outside the deadband AND flat for the full window → settled systematic bias.
  ; Compute the bounded (±5% absolute vs current e-steps) target. It is NOT applied here —
  ; M92 blocks. filament-error.g applies it at standstill on the next MFM error pause.
  ; Stepping is unchanged at detection time, so stepsPerMm IS the baseline.
  var base = move.extruders[0].stepsPerMm
  var lo = {var.base * 0.95}
  var hi = {var.base * 1.05}
  var ideal = {var.base * 100 / var.avg}
  set global.mfm_esteps_suggested = max(var.lo, min(var.hi, var.ideal))
  set global.mfm_esteps_detected = true
  M118 P3 S{"MFM flow bias " ^ var.avg ^ "% - recalibrate e-steps to ~" ^ global.mfm_esteps_suggested}
