; Parameter P description
; 2 = noDataReceived
; 3 = noFilament
; 4 = tooLittleMovement
; 5 = tooMuchMovement
; 6 = SensorError
; 7 = Magnet to weak
; 8 = Magnet to strong

if exists(global.ignoreMFMevents) && global.ignoreMFMevents == true
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

    if global.mfmbackoff > 0
        M220 S{20*global.mfmbackoff} ; reduce speed in steps 3*20=60% 2*20=40% 1*20=20%
        set global.mfmbackoff = global.mfmbackoff - 1
        if global.debug
          echo "MFM: backoff counter " ^ global.mfmbackoff
        M99

    ; Backoff exhausted — pause, auto-recover, resume if successful
    set global.mfmbackoff = 3
    M220 S100                            ; revert speed change to 100%
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
