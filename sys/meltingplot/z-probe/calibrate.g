; z-probe/calibrate.g
; Calibrates the scanning Z probe at the current temperature: at the bed centre, in the Z frame
; z-probe/scan-contact.g has just set (Z0 = where the nozzle lifts off the bed), nozzle hot.
; Macro calibration/z-height runs it cold and warm.
;   M98 P"0:/sys/meltingplot/z-probe/calibrate.g" S"cold"|"warm" [H1]
; S  = the files to write, sys/generated/szp-{standard,touch}-mode-<S>.g; z-probe/standard-mode.g
;      and touch-mode.g load them by the coil temperature (global.szp_warm_threshold)
; H1 = take the measured touch stop height over as global.szp_touch_z_offset and save it
;      (macro z-probe/offset/save); without H1 it is only reported
; Three steps:
; - standard mode: the lowest drive current that reads at its dive start, and the reading
;   offset that puts the threshold of z-probe/standard-mode.g (G31 P9000) at the trigger
;   height - a standard-mode G30 stops near Z3 even before homez.g's M558.1 calibrates the
;   height curve against the touch datum;
; - touch mode: the lowest drive current, from the standard one up, that reads from the touch
;   start down to the contact - the SZP board takes three invalid readings as a touch. No
;   reading offset: the board detects the touch on the raw reading through a 5-25 Hz bandpass
;   (Duet3Expansion ScanningSensorHandler.cpp), an offset never reaches it;
; - touch stop height: Duet's touch calibration - "use the reported G30 S-1 stop height as the
;   M558.3 H parameter" (wiki, scanning_z_probe_calibration) - averaged over five touches.
;   homez.g sets Z = H where its touch stops, so this H puts Z0 on the contact.
;   sensors.probes[0].lastStopHeight is the raw stop Z (GCodes4.cpp), whatever H is set now.
; Returns global.result 0, or 1 when a step failed (reason echoed, bed at Z5).

set global.result = 1                            ; every exit before the end is a failure
if !exists(param.S) || (("" ^ param.S) != "cold" && ("" ^ param.S) != "warm")
  echo "Error: z-probe/calibrate.g needs S set to cold or warm"
  M99

var error = ""
var current = 15                                 ; drive current - standard mode's, then touch mode's
var standard = 0                                 ; standard mode's, for the report
var offset = 0                                   ; standard mode's reading offset
G90

; standard mode: lowest drive current that reads at the dive start (trigger + 1.5 dive heights)
M98 P"0:/sys/meltingplot/z-probe/standard-mode.g"
G1 Z{sensors.probes[0].triggerHeight + sensors.probes[0].diveHeights[0] * 1.5} F600
M400
while true
  M558.2 K0 S{var.current} R0
  M400
  G4 S1                                          ; let the sensor settle on the new current
  if sensors.probes[0].value[0] < 999999
    break
  set var.current = var.current + 1
  if var.current > 31
    set var.error = "no SZP drive current reads in standard mode at Z" ^ move.axes[2].userPosition
    break

if var.error == ""
  set var.standard = var.current
  G1 Z{sensors.probes[0].triggerHeight} F600
  M400
  G4 S1
  if sensors.probes[0].value[0] >= 999999
    set var.error = "SZP reading invalid at the standard trigger height Z" ^ sensors.probes[0].triggerHeight
  else
    set var.offset = sensors.probes[0].value[0] - 9000
    M558.2 K0 S{var.current} R{var.offset}
    echo >{"0:/sys/generated/szp-standard-mode-" ^ param.S ^ ".g"} "M558.2 K0 S" ^ var.current ^ " R" ^ var.offset

; touch mode: lowest drive current that reads at the touch start and on the bed (Z0)
if var.error == ""
  M98 P"0:/sys/meltingplot/z-probe/touch-mode.g"
  while true
    G1 Z{sensors.probes[0].diveHeights[0] * 1.2} F600
    M400
    M558.2 K0 S{var.current} R0
    G4 S1
    if sensors.probes[0].value[0] < 999999
      G1 Z0 F300                                 ; nozzle on the bed
      M400
      G4 S1
      if sensors.probes[0].value[0] < 999999
        break
    set var.current = var.current + 1
    if var.current > 31
      set var.error = "no SZP drive current reads in touch mode from Z" ^ {sensors.probes[0].diveHeights[0] * 1.2} ^ " down to the contact"
      break
  if var.error == ""
    echo >{"0:/sys/generated/szp-touch-mode-" ^ param.S ^ ".g"} "M558.2 K0 S" ^ var.current ^ " R0"

; touch stop height, five touches with the drive current just found (touch-mode.g above
; loaded the file of the coil's temperature, M558.2 then set this one)
var h = 0
var spread = 0
if var.error == ""
  var h_sum = 0
  var h_min = 1000
  var h_max = -1000
  while iterations < 5
    G1 Z5 F600                                   ; a touch must start with the nozzle above the bed
    M400
    G30 K0 S-1
    if result > 1                                ; 1 = warning (M558 A2 readings outside S0.05) - the spread below judges that
      set var.error = "touch " ^ (iterations + 1) ^ " of 5 failed"
      break
    set var.h_sum = var.h_sum + sensors.probes[0].lastStopHeight
    set var.h_min = min(var.h_min, sensors.probes[0].lastStopHeight)
    set var.h_max = max(var.h_max, sensors.probes[0].lastStopHeight)
  if var.error == ""
    set var.h = {round(var.h_sum * 200) / 1000}  ; mean of the five, to 0.001 mm
    set var.spread = var.h_max - var.h_min

G1 Z5 F600
M400

if var.error == ""
  echo "z-probe/calibrate.g " ^ param.S ^ ": standard mode S" ^ var.standard ^ " R" ^ var.offset ^ ", touch mode S" ^ var.current
  echo "z-probe/calibrate.g " ^ param.S ^ ": touch stops at Z" ^ var.h ^ " (spread " ^ var.spread ^ " over 5 touches) - szp_touch_z_offset " ^ global.szp_touch_z_offset
  ; a touch stops a little below the contact (the board needs a few readings to see the
  ; reading stop rising), and five touches agree - both limits are guesses for the first runs
  if var.spread > 0.05 || var.h > 0.1 || var.h < -1
    if exists(param.H) && param.H == 1
      set var.error = "touch stop height Z" ^ var.h ^ " (spread " ^ var.spread ^ ") implausible - szp_touch_z_offset kept"
    else
      M118 P0 L1 S{"Warning: " ^ param.S ^ " touch stop height Z" ^ var.h ^ " (spread " ^ var.spread ^ ") implausible"}
  elif exists(param.H) && param.H == 1
    set global.szp_touch_z_offset = var.h
    M98 P"0:/macros/meltingplot/z-probe/offset/save"

if var.error != ""
  echo "Error: " ^ var.error
  M99

set global.result = 0
