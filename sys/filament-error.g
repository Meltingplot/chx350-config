; Parameter P description
; 2 = noDataReceived
; 3 = noFilament
; 4 = tooLittleMovement
; 5 = tooMuchMovement
; 6 = SensorError
; 7 = Magnet to weak
; 8 = Magnet to strong

; Apply a pending daemon-detected flow-bias e-steps correction FIRST, before any other handling.
; Must be here (not after the pause): a resume reloads e-steps from the filament config and would
; wipe an M92 applied later, so it is applied on the first error — typically still in the backoff
; phase, which does not pause/resume — so it sticks and can resolve the bias before it escalates to
; a hard pause. M92 blocks (LockAllMovementSystemsAndWaitForStandstill): it stalls this trigger
; until the move queue drains, which is harmless because filament-error.g runs out of band — but it
; would freeze the safety loop and MUST NEVER run in daemon.g. Bounded ±5% (clamped at detection),
; applied once per print (mfm_esteps_baseline == 0 guard); print_end restores the baseline.
if global.mfm_esteps_suggested != 0 && global.mfm_esteps_baseline == 0
  set global.mfm_esteps_baseline = move.extruders[0].stepsPerMm
  M92 E{global.mfm_esteps_suggested}
  echo "MFM: applied flow-bias e-steps correction " ^ global.mfm_esteps_baseline ^ " -> " ^ global.mfm_esteps_suggested

if exists(global.ignoreMFMevents) && global.ignoreMFMevents == true
  ; During suppression, still enforce distance limit for stuck spool detection —
  ; but only when an active running job could actually be hard-paused. Otherwise
  ; (calibration, manual loading, paused state) the bypass's side effects would
  ; leak: it clears ignoreMFMevents/mfm_suppress_until and falls through to the
  ; backoff path which calls M220 — that would corrupt the calibration feedrate.
  if (param.P == 4 || param.P == 5) && global.mfm_error_extruder_ref != null && job.file.fileName != null && state.status != "paused"
    if abs(move.extruders[0].position - global.mfm_error_extruder_ref) >= 30
      ; Distance exceeded during suppression — cancel suppression, fall through to hard pause
      set global.ignoreMFMevents = false
      set global.mfm_suppress_until = 0
    else
      M99
  else
    M99

if !exists(global.mfmbackoff)
  global mfmbackoff = 3

if !exists(global.lastMFMBackoffCheck)
  global lastMFMBackoffCheck = state.upTime

if param.P == 2 || param.P == 6
    if global.debug
      echo "MFM: sensor error P=" ^ param.P ^ " (sensor " ^ param.D ^ ") — continuing"
    M99

if param.P == 4
    if global.debug
      echo "MFM: P=4 too little movement (sensor " ^ param.D ^ ")"

if param.P == 5
    if exists(global.mfm_swing_count) && global.mfm_swing_count > 0
        if global.debug
          echo "MFM: P=5 suppressed — rebound from large swing (count=" ^ global.mfm_swing_count ^ ")"
        M220 S100
        set global.mfmbackoff = 3
        M99
    if global.debug
      echo "MFM: P=5 too much movement (sensor " ^ param.D ^ ")"

; --- Common backoff / pause / auto-recovery for P=4 and P=5 ---
if param.P == 4 || param.P == 5
    set global.lastMFMBackoffCheck = state.upTime
    set global.mfm_normal_since = 0

    ; Track extruder distance since first error in this sequence
    if global.mfm_error_extruder_ref == null
      set global.mfm_error_extruder_ref = move.extruders[0].position

    var error_dist = abs(move.extruders[0].position - global.mfm_error_extruder_ref)

    ; Within safety margin and backoff attempts remaining — reduce speed
    if var.error_dist < 30 && global.mfmbackoff > 0
        M220 S{20*global.mfmbackoff} ; reduce speed in steps 3*20=60% 2*20=40% 1*20=20%
        set global.mfmbackoff = global.mfmbackoff - 1
        if global.debug
          echo "MFM: backoff counter " ^ global.mfmbackoff ^ " (dist=" ^ var.error_dist ^ "mm)"
        M99

    ; Hard pause — backoff exhausted or 30mm safety distance exceeded
    if global.debug
      if var.error_dist >= 30
        echo "MFM: " ^ var.error_dist ^ "mm extruded during error sequence — hard pause"
      else
        echo "MFM: backoff exhausted — pause"
    set global.mfm_error_extruder_ref = null
    set global.mfm_normal_since = 0
    set global.mfmbackoff = 3
    M220 S100                            ; revert speed change to 100%

    ; Only proceed to M25 + auto-recovery when an active running job exists
    ; (state.status "processing" is also true for macros, so gate on job file)
    if job.file.fileName == null || state.status == "paused"
      if global.debug
        echo "MFM: hard-pause skipped (state=" ^ state.status ^ ", no active job)"
      M99

    ; Heater PWM fast-fail: check before pause (standby drops avgPwm)
    ; Below threshold = definitely not extruding = real issue; above is inconclusive
    if heat.heaters[1].avgPwm < 0.15
      echo "MFM: heater PWM low (" ^ {heat.heaters[1].avgPwm} ^ ") — confirms real issue"
      M25
      M400
      T-1 P0
      M291 P{"Filament Sensor " ^ param.D ^ ": issue confirmed (heater PWM low). Check filament and resume."} S1 T0
      M99

    ; Loop breaker: a hard pause this soon after a successful auto-recovery means the
    ; pass verdict didn't hold (e.g. regrind from a downstream cause the purge-through
    ; can't fix) — skip the test, stay paused for the operator. Cleared here so the
    ; next hard pause after an operator resume gets a fresh auto-recovery attempt.
    if global.mfm_recovery_last_ok != 0 && (state.upTime - global.mfm_recovery_last_ok) < 300
      set global.mfm_recovery_last_ok = 0
      M25
      M400
      T-1 P0
      M291 P{"Filament Sensor " ^ param.D ^ ": repeated error shortly after auto-recovery. Check filament for grinding and resume."} S1 T0
      M99

    ; The auto-recovery runs INSIDE pause.g (armed via mfm_recovery_requested), so the firmware
    ; state is still "pausing" while it moves and purges: M24 is ignored and DWC is locked on every
    ; channel until pause.g returns. Running it here, after the pause committed, let an operator
    ; resume interleave with the purge (2026-09-03). pause.g hands the verdict back in
    ; mfm_recovery_last_result (-1 = recovery never ran, e.g. M25 rejected).
    set global.mfm_recovery_last_result = -1
    set global.mfm_recovery_requested = true
    M25                                  ; pause.g: retract, park, standby, auto-recovery, then paused
    set global.mfm_recovery_requested = false   ; a rejected M25 must not arm the next ordinary pause
    M400

    if global.mfm_recovery_last_result != 0
        ; Recovery failed or never ran — tool already deselected by pause.g, stay paused for operator
        if param.P == 4
          M291 P{"Filament Sensor " ^ param.D ^ ": issue confirmed. Check filament and resume."} S1 T0
        else
          M291 P{"Filament Sensor " ^ param.D ^ ": Too much Filament movement - Possible Reasons: Spool skipped or Filament pushed into PTFE tube."} S1 T0
        M99

    ; False positive confirmed — auto-resume (resume.g re-selects the tool via T R1)
    set global.mfm_recovery_last_ok = state.upTime
    if global.debug
      echo "MFM: false positive — auto-resuming"
    M24
    M99

; Fallback for other error types (P=3, P=7, P=8)
if job.file.fileName == null || state.status == "paused"
  if global.debug
    echo "MFM: fallback pause skipped (state=" ^ state.status ^ ", no active job)"
  M99

echo "Filament error: " ^ param.P ^ " on sensor " ^ param.D ^ " - paused"
M291 P{"Filament Sensor " ^ param.D ^ ": " ^ param.S ^ " - Paused"} S1 T0
M25 ; pause
