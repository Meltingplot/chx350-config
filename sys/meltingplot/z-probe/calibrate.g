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
; - standard mode: the middle of the window of drive currents that read valid at every height
;   standard mode works at, and the reading offset that puts the threshold of
;   z-probe/standard-mode.g (G31 P9000) at the trigger height - a standard-mode G30
;   (z-probe/coarse-level.g) stops near Z3; mesh.g calibrates its height curve with this
;   drive current;
; - touch mode: the lowest drive current, from S15 or the standard window's low edge up, that
;   reads from the touch start down to the contact - the SZP board takes three invalid
;   readings as a touch. No
;   reading offset: the board detects the touch on the raw reading through a 5-25 Hz bandpass
;   (Duet3Expansion ScanningSensorHandler.cpp), an offset never reaches it;
; - touch stop height: Duet's touch calibration - "use the reported G30 S-1 stop height as the
;   M558.3 H parameter" (wiki, scanning_z_probe_calibration) - averaged over five touches.
;   homez.g sets Z = H where its touch stops, so this H puts Z0 on the contact.
;   sensors.probes[0].lastStopHeight is the raw stop Z (GCodes4.cpp), whatever H is set now.
; A reading is invalid at 999999 (the SZP board's error value) and at 0 (the board could not
; read the LDC1612) - RRF takes both as errors (RemoteZProbe.cpp).
; Returns global.result 0, or 1 when a step failed (reason echoed, bed at Z5).

set global.result = 1                            ; every exit before the end is a failure
if !exists(param.S) || (("" ^ param.S) != "cold" && ("" ^ param.S) != "warm")
  echo "Error: z-probe/calibrate.g needs S set to cold or warm"
  M99

var error = ""
var current = 15                                 ; drive current - standard mode's, then touch mode's
var standard = 0                                 ; standard mode's, for the report
var offset = 0                                   ; standard mode's reading offset
; declared once, set in the loops: DSF loses track of loop variables (see z-probe/scan-contact.g)
var r = 0                                        ; a board report
var r1 = 0                                       ; three board reports at rest
var r2 = 0
var r3 = 0
var s_first = 10                                 ; the drive currents tried for standard mode: S10..S24
var ok = vector(15, true)                        ; ok[i]: S(s_first + i) read valid at every height so far
var k = 0                                        ; index of the height being tried
var run_lo = -1                                  ; start of the run of valid currents being counted
var win_lo = -1                                  ; the window: the longest run, as indices into ok
var win_hi = -2
var window = ""                                  ; the window as text, for the messages
var coil = sensors.analog[4].lastReading         ; coil temperature, reported with the result
G90

; Standard mode: the window of drive currents that read valid at every height standard mode
; works at, and its middle. Z12 is the dive start (trigger + 1.5 dive heights): coarse-level.g's
; reading check, and its G30 start at Z9 below it. Z3 is the trigger height: the threshold, and
; the height mesh.g scans at. Z1.8 is the bottom of mesh.g's height curve (M558.1 S1.2).
; A current too low reads 999999 close to the bed, one too high far from it (M558.2), so the
; window has two edges, and they move with the coil temperature: on the lab machine
; (2026-10-28) S15 and S16 read at every height cold and warm, warm S14 fails from Z5 down and
; S17 only at Z600. The rule before - the lowest current that reads at Z12 - sat on the low
; edge, where close readings fail first. mesh.g's M558.2 S-1, which mesh.g used until this
; calibration replaced it, picked S16 at all six meshes of 2026-10-08..11-12: the middle of the
; warm window. A current counts as valid at a height only when three board reports at rest
; are; one that failed at a height is not tried at the next. Of an even window the lower
; middle current is taken.
M98 P"0:/sys/meltingplot/z-probe/standard-mode.g"
var heights = {sensors.probes[0].triggerHeight + sensors.probes[0].diveHeights[0] * 1.5, sensors.probes[0].triggerHeight, sensors.probes[0].triggerHeight - 1.2}
while iterations < #var.heights
  set var.k = iterations
  G1 Z{var.heights[var.k]} F600
  M400
  while iterations < #var.ok
    if var.ok[iterations]
      M558.2 K0 S{var.s_first + iterations} R0
      G4 S1                                      ; let the sensor settle on the new current
      set var.r1 = sensors.probes[0].value[0]
      G4 P250                                    ; the SZP board reports every 250 ms
      set var.r2 = sensors.probes[0].value[0]
      G4 P250
      set var.r3 = sensors.probes[0].value[0]
      if max(var.r1, var.r2, var.r3) >= 999999 || min(var.r1, var.r2, var.r3) <= 0
        set var.ok[iterations] = false
      if global.debug
        echo "z-probe/calibrate.g: standard S" ^ (var.s_first + iterations) ^ " at Z" ^ var.heights[var.k] ^ ": " ^ var.r1 ^ " " ^ var.r2 ^ " " ^ var.r3

; the longest run of valid currents; of two equally long the lower one
while iterations < #var.ok
  if !var.ok[iterations]
    set var.run_lo = -1
  else
    if var.run_lo < 0
      set var.run_lo = iterations
    if iterations - var.run_lo > var.win_hi - var.win_lo
      set var.win_lo = var.run_lo
      set var.win_hi = iterations
if var.win_lo < 0
  set var.error = "no SZP drive current S" ^ var.s_first ^ "..S" ^ (var.s_first + #var.ok - 1) ^ " reads in standard mode at Z" ^ var.heights[0] ^ ", Z" ^ var.heights[1] ^ " and Z" ^ var.heights[2]
else
  set var.current = var.s_first + floor((var.win_lo + var.win_hi) / 2)
  set var.window = "S" ^ (var.s_first + var.win_lo) ^ "..S" ^ (var.s_first + var.win_hi)
  if var.win_lo == 0 || var.win_hi == #var.ok - 1
    ; the window may reach beyond the currents tried, its middle then lies off
    M118 P0 L1 S{"Warning: SZP standard mode window " ^ var.window ^ " reaches the edge of the currents tried"}

if var.error == ""
  set var.standard = var.current
  G1 Z{sensors.probes[0].triggerHeight} F600
  M400
  M558.2 K0 S{var.current} R0
  G4 S1
  set var.r1 = sensors.probes[0].value[0]
  G4 P250
  set var.r2 = sensors.probes[0].value[0]
  G4 P250
  set var.r3 = sensors.probes[0].value[0]
  if max(var.r1, var.r2, var.r3) >= 999999 || min(var.r1, var.r2, var.r3) <= 0
    set var.error = "SZP reading invalid at the standard trigger height Z" ^ sensors.probes[0].triggerHeight
  else
    ; the median of the three, so that 9000 lies at the trigger height
    set var.offset = var.r1 + var.r2 + var.r3 - max(var.r1, var.r2, var.r3) - min(var.r1, var.r2, var.r3) - 9000
    M558.2 K0 S{var.current} R{var.offset}
    echo >{"0:/sys/generated/szp-standard-mode-" ^ param.S ^ ".g"} "; drive current window " ^ var.window ^ ", coil " ^ var.coil ^ " C - written by z-probe/calibrate.g"
    echo >>{"0:/sys/generated/szp-standard-mode-" ^ param.S ^ ".g"} "M558.2 K0 S" ^ var.current ^ " R" ^ var.offset

; touch mode: lowest drive current that reads at the touch start and on the bed (Z0). The search
; starts where it did while standard mode took the lowest current reading at Z12 - at S15 - or
; at the standard window's low edge when that lies higher: a current below it already failed
; close to the bed in standard mode
if var.error == ""
  set var.current = max(15, var.s_first + var.win_lo)
  M98 P"0:/sys/meltingplot/z-probe/touch-mode.g"
  while true
    G1 Z{sensors.probes[0].diveHeights[0] * 1.2} F600
    M400
    M558.2 K0 S{var.current} R0
    G4 S1
    set var.r = sensors.probes[0].value[0]
    if var.r < 999999 && var.r > 0
      G1 Z0 F300                                 ; nozzle on the bed
      M400
      G4 S1
      set var.r = sensors.probes[0].value[0]
      if var.r < 999999 && var.r > 0
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
  echo "z-probe/calibrate.g " ^ param.S ^ ": standard mode S" ^ var.standard ^ " (window " ^ var.window ^ ") R" ^ var.offset ^ ", touch mode S" ^ var.current ^ ", coil " ^ var.coil ^ " C"
  echo "z-probe/calibrate.g " ^ param.S ^ ": touch stops at Z" ^ var.h ^ " (spread " ^ var.spread ^ " over 5 touches) - szp_touch_z_offset " ^ global.szp_touch_z_offset
  ; a touch stops a little below the contact (the board needs a few readings to see the
  ; reading stop rising), never above it: -0.03..-0.02 on the lab machine, -0.062 cold on a
  ; 3.6 machine, whose warm +0.089 (2026-11-17) came from a scan that had put Z0 0.15 mm too
  ; deep. Five touches agree. The limits are still guesses from these few runs.
  if var.spread > 0.05 || var.h > 0.02 || var.h < -1
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
