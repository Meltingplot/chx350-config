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
    G4 S2                                ; let pause.g settle

    ; Auto-recovery: verify filament while paused
    set global.result = 0
    M98 P"0:/sys/meltingplot/mfm_auto_recovery"

    if global.result != 0
        ; Recovery failed — real issue, stay paused for operator
        if param.P == 4
          M291 P{"Filament Sensor " ^ param.D ^ ": issue confirmed. Check filament and resume."} S1 T0
        else
          M291 P{"Filament Sensor " ^ param.D ^ ": Too much Filament movement - Possible Reasons: Spool skipped or Filament pushed into PTFE tube."} S1 T0
        M99

    ; False positive confirmed — resume inline
    ; Re-activate heater (pause.g set standby via T-1 P0)
    M568 P0 A2
    M106 R1                              ; restore fan to pre-pause state
    G90
    G1 R1 X0 Y0 U0 F60000              ; pre-position while heater warms up

    if global.debug
      echo "MFM: false positive — re-heating and pre-positioning for auto-resume"

    ; Wait for heater to reach active temp (with timeout and door checks)
    var deadline = state.upTime + 600    ; 10 min timeout
    while heat.heaters[tools[0].heaters[0]].current < heat.heaters[tools[0].heaters[0]].active
      if iterations > 6000
        break
      if state.upTime >= var.deadline
        M291 P"Auto-resume timed out after 10 minutes. Check filament and resume manually." S1 T0
        M99
      if global.door_left_open || global.door_right_open
        M291 P"Auto-resume cancelled — door was opened. Resume manually when ready." S1 T0
        M99
      G4 P100                            ; poll every 100ms

    ; Final door check before resuming
    if global.door_left_open || global.door_right_open
      M291 P"Auto-resume cancelled — door was opened. Resume manually when ready." S1 T0
      M99

    if global.debug
      echo "MFM: auto-resuming after false positive recovery"
    M24
    M99

; Fallback for other error types (P=3, P=7, P=8)
echo "Filament error: " ^ param.P ^ " on sensor " ^ param.D ^ " - paused"
M291 P{"Filament Sensor " ^ param.D ^ ": " ^ param.S ^ " - Paused"} S1 T0
M25 ; pause
