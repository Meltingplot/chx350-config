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
    if exists(global.mfmcalibration) && global.mfmcalibration == true
        M92 E{move.extruders[0].stepsPerMm+0.5}
        echo "E-Steps: " ^ {move.extruders[0].stepsPerMm} ^ ""
    else
        if global.debug
          echo "MFM: P=4 too little movement (sensor " ^ param.D ^ ")"
        
        set global.lastMFMBackoffCheck = state.upTime

        if global.mfmbackoff == 0
            set global.mfmbackoff = 3
            M220 S100 ; revert speed change to 100%
            ; Pause print first — print is still running on the file channel
            M25
            G4 S2                            ; let pause.g settle
            ; Auto-recovery: verify filament while paused
            set global.result = 0
            M98 P"0:/sys/meltingplot/mfm_auto_recovery"
            if global.result == 0
              ; False positive confirmed — defer resume to daemon.g
              ; (M24 here would fail: pause.g may not have completed yet)
              set global.auto_resume = true
            else
              ; Recovery failed — real issue, stay paused for customer
              M291 P{"Filament Sensor " ^ param.D ^ ": issue confirmed. Check filament and resume."} S1 T0
        else
            M220 S{20*global.mfmbackoff} ; reduce speed in steps 3*20=60% 2*20=40% 1*20=20%
            set global.mfmbackoff = global.mfmbackoff - 1
            if global.debug
              echo "MFM: backoff counter " ^ global.mfmbackoff

    M99 ; leave macro

if param.P == 5
    if exists(global.mfmcalibration) && global.mfmcalibration == true
        M92 E{move.extruders[0].stepsPerMm-0.5}
        echo "E-Steps: " ^ {move.extruders[0].stepsPerMm} ^ ""
    else
        if exists(global.mfm_swing_count) && global.mfm_swing_count > 0
            if global.debug
              echo "MFM: P=5 suppressed — rebound from large swing (count=" ^ global.mfm_swing_count ^ ")"
            M220 S100
            set global.mfmbackoff = 3
        else
            if global.debug
              echo "MFM: P=5 too much movement (sensor " ^ param.D ^ ")"

            set global.lastMFMBackoffCheck = state.upTime

            if global.mfmbackoff == 0
                set global.mfmbackoff = 3
                M220 S100 ; revert speed change to 100%
                ; Pause print first — print is still running on the file channel
                M25
                G4 S2                            ; let pause.g settle
                ; Auto-recovery: verify filament while paused
                set global.result = 0
                M98 P"0:/sys/meltingplot/mfm_auto_recovery"
                if global.result == 0
                  ; False positive confirmed — defer resume to daemon.g
                  set global.auto_resume = true
                else
                  ; Recovery failed — real issue, stay paused for customer
                  M291 P{"Filament Sensor " ^ param.D ^ ": Too much Filament movement - Possible Reasons: Spool skipped or Filament pushed into PTFE tube."} S1 T0
            else
                M220 S{20*global.mfmbackoff} ; reduce speed in steps 3*20=60% 2*20=40% 1*20=20%
                set global.mfmbackoff = global.mfmbackoff - 1
                if global.debug
                  echo "MFM: P=5 backoff counter " ^ global.mfmbackoff
        
    M99 ; leave macro

echo "Filament error: " ^ param.P ^ " on sensor " ^ param.D ^ " - paused"
M291 P{"Filament Sensor " ^ param.D ^ ": " ^ param.S ^ " - Paused"} S1 T0
M25 ; pause