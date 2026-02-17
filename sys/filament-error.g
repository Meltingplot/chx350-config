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
    echo "Filament Sensor Error: " ^ param.P ^ "  sensor : " ^ param.D ^ " - continue printing"
    M99

if param.P == 4
    if exists(global.mfmcalibration) && global.mfmcalibration == true
        M92 E{move.extruders[0].stepsPerMm+0.5}
        echo "E-Steps: " ^ {move.extruders[0].stepsPerMm} ^ ""
    else
        echo "Filament Sensor " ^ param.D ^ ": Too little Filament movement - Possible Reasons: Filament empty, grinding or clogged nozzle."
        
        set global.lastMFMBackoffCheck = state.upTime

        if global.mfmbackoff == 0
            set global.mfmbackoff = 3
            M220 S100 ; revert speed change to 100%
            M291 P{"Filament Sensor " ^ param.D ^ ": Too little Filament movement - Possible Reasons: Filament empty, grinding or clogged nozzle."} S1 T0
            G11 ; unretract
            M25 ; pause print
        else
            M220 S{20*global.mfmbackoff} ; reduce speed in steps 3*20=60% 2*20=40% 1*20=20%
            set global.mfmbackoff = global.mfmbackoff - 1
            echo "Filament Sensor Backoffcounter: " ^ global.mfmbackoff ^ ""
        
    M99 ; leave macro

if param.P == 5
    if exists(global.mfmcalibration) && global.mfmcalibration == true
        M92 E{move.extruders[0].stepsPerMm-0.5}
        echo "E-Steps: " ^ {move.extruders[0].stepsPerMm} ^ ""
    else
        echo "Filament Sensor " ^ param.D ^ ": Too much Filament movement - Possible Reasons: Spool skipped or Filament pushed into PTFE tube."
        M291 P{"Filament Sensor " ^ param.D ^ ": Too much Filament movement - Possible Reasons: Spool skipped or Filament pushed into PTFE tube."} S1 T0
        G11 ; unretract
        M25 ; pause print
        
    M99 ; leave macro

echo "Filament error: " ^ param.P ^ " on sensor " ^ param.D ^ " - paused"
M291 P{"Filament Sensor " ^ param.D ^ ": " ^ param.S ^ " - Paused"} S1 T0
G11 ; unretract
M25 ; pause