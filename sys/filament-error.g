; Parameter P description
; 2 = noDataReceived
; 3 = noFilament
; 4 = tooLittleMovement
; 5 = tooMuchMovement
; 6 = SensorError
; 7 = Magnet to weak
; 8 = Magnet to strong

if exists(global.ignoreMFMevents) && global.ignoreMFMevents == true
  ; During suppression, still enforce distance limit for stuck spool detection
  if (param.P == 4 || param.P == 5) && global.mfm_error_extruder_ref != null
    if abs(move.extruders[0].position - global.mfm_error_extruder_ref) >= 40
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
    if var.error_dist < 40 && global.mfmbackoff > 0
        M220 S{20*global.mfmbackoff} ; reduce speed in steps 3*20=60% 2*20=40% 1*20=20%
        set global.mfmbackoff = global.mfmbackoff - 1
        if global.debug
          echo "MFM: backoff counter " ^ global.mfmbackoff ^ " (dist=" ^ var.error_dist ^ "mm)"
        M99

    ; Hard pause — backoff exhausted or 40mm safety distance exceeded
    if global.debug
      if var.error_dist >= 40
        echo "MFM: " ^ var.error_dist ^ "mm extruded during error sequence — hard pause"
      else
        echo "MFM: backoff exhausted — pause"
    set global.mfm_error_extruder_ref = null
    set global.mfm_normal_since = 0
    set global.mfmbackoff = 3
    M220 S100                            ; revert speed change to 100%

    ; Heater PWM fast-fail: check before pause (standby drops avgPwm)
    ; Below threshold = definitely not extruding = real issue; above is inconclusive
    if heat.heaters[1].avgPwm < 0.15
      echo "MFM: heater PWM low (" ^ {heat.heaters[1].avgPwm} ^ ") — confirms real issue"
      M25
      M400
      T-1 P0
      M291 P{"Filament Sensor " ^ param.D ^ ": issue confirmed (heater PWM low). Check filament and resume."} S1 T0
      M99

    M25                                  ; pause print (pause.g: retract, park, standby heater, fan off)
    M400                                 ; wait for pause.g to complete

    ; Re-select tool for auto-recovery (pause.g deselects via T-1 P0)
    T R1 P0                                ; restore last tool without tpre/tpost

    ; Auto-recovery: verify filament while paused
    set global.result = 0
    M98 P"0:/sys/meltingplot/mfm_auto_recovery"

    if global.result != 0
        ; Recovery failed — deselect tool so resume.g can re-select, stay paused for operator
        T-1 P0
        if param.P == 4
          M291 P{"Filament Sensor " ^ param.D ^ ": issue confirmed. Check filament and resume."} S1 T0
        else
          M291 P{"Filament Sensor " ^ param.D ^ ": Too much Filament movement - Possible Reasons: Spool skipped or Filament pushed into PTFE tube."} S1 T0
        M99

    ; False positive confirmed — deselect tool so resume.g can re-select via T R1
    T-1 P0
    if global.debug
      echo "MFM: false positive — auto-resuming"
    M24
    M99

; Fallback for other error types (P=3, P=7, P=8)
echo "Filament error: " ^ param.P ^ " on sensor " ^ param.D ^ " - paused"
M291 P{"Filament Sensor " ^ param.D ^ ": " ^ param.S ^ " - Paused"} S1 T0
M25 ; pause
