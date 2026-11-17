; z-probe/coarse-level.g
; Levels the bed coarsely and without any contact, right after align_z_axis.g has squared it
; against its lower stops and before a nozzle comes near it: homez.g runs it before its centre
; touch, calibrate_z_height_automatic before its first scan.
; A Z motor that stalls before its stop leaves its corner high - 3-4 mm on a 3.6 machine
; (2026-11-17). bed.g's touch probes travel at their starting height, touch H + dive 2, about
; 1.9 mm above the centre (RRF GCodes4.cpp probingAtPoint0/1: to the starting height first,
; then across), so that corner crashed the nozzle on the way to P1; a high corner under
; another part braked two scans of the same day before the nozzle at the centre touched.
; Here the probe works in standard mode: G30 at bed.g's four points travels at trigger height
; + dive (3 + 6 = 9 mm) and stops where the reading crosses the threshold, about 3 mm above
; the surface (the reading offset z-probe/calibrate.g sets; 3.0-3.1 mm on that machine) - no
; contact, and at most twice the dive deep, down to Z-3. Only the tilt is corrected: G30 with
; the four heights less their mean and S4 - RRF takes a given Z as the height error without
; probing (GCodes6.cpp) - so the leadscrews level the bed without moving it at the centre,
; and the Z frame align_z_axis.g set from the measured Z max stays the one the centre touch
; relies on. Up to three passes, until no point lies more than 0.3 mm off their mean; each
; correction is limited to 5 mm (M671 S5), a larger one fails.
; Before probing, the reading at rest above the centre must be steady and rise from Z12 to
; Z8: a frozen reading would never cross the threshold, and the probe would run to Z-3.
; Returns global.result 0, or 1 on failure (reason echoed, bed 10 mm lower). Leaves the probe
; in standard mode. Expects X, Y, U and Z homed.

set global.result = 1                            ; every exit before the end is a failure
if !move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed || !move.axes[3].homed
  echo "Error: z-probe/coarse-level.g needs X, Y, U and Z homed"
  M99

; declared once, only set in the loops: DSF loses track of variables a loop body declares
; (z-probe/scan-contact.g)
var error = ""
var r1 = 0                                       ; three board reports at rest
var r2 = 0
var r3 = 0
var v12 = 0                                      ; their median above the centre at Z12 and Z8
var v8 = 0
var h0 = 0                                       ; bed height at the four points (stop - trigger height)
var h1 = 0
var h2 = 0
var h3 = 0
var mean = 0
var off = 0                                      ; the largest distance of a point from their mean
var pass = 0
var height = 12                                  ; where above the centre the reading is taken
var tries = 0                                    ; readings at this height that failed

G90
M561                                             ; heights without bed transform, mesh or babystepping
G29 S2
M290 R0 S0
M98 P"0:/sys/meltingplot/z-probe/szp_standard_mode.g"
G1 Z20 F6000
G1 X{move.axes[0].max/2} Y{move.axes[1].max/2} U{move.axes[3].max} F60000

; the reading above the centre: valid, steady at rest (as in z-probe/scan-contact.g: a quiet
; probe spreads a few counts) and rising as the bed comes closer. Three tries per height, a
; second apart: on the 3.6 machine of 2026-11-17 single invalid reports came and went (homing
; failed on the first one, 18:31). The values go into the message.
while true
  if iterations > 10
    set var.error = "the reading check above the bed centre did not end"
    break
  G1 Z{var.height} F600
  M400
  G4 P400
  set var.r1 = sensors.probes[0].value[0]
  G4 P250
  set var.r2 = sensors.probes[0].value[0]
  G4 P250
  set var.r3 = sensors.probes[0].value[0]
  if max(var.r1, var.r2, var.r3) >= 999999 || min(var.r1, var.r2, var.r3) <= 0 || max(var.r1, var.r2, var.r3) - min(var.r1, var.r2, var.r3) > 30
    set var.tries = var.tries + 1
    if global.debug
      echo "coarse-level: reading above the centre at Z" ^ var.height ^ ": " ^ var.r1 ^ " " ^ var.r2 ^ " " ^ var.r3 ^ " - try " ^ var.tries
    if var.tries >= 3
      set var.error = "SZP reading invalid or jumping above the bed centre at Z" ^ var.height ^ " (" ^ var.r1 ^ " " ^ var.r2 ^ " " ^ var.r3 ^ ", 3 tries) - check coil, cable and connector"
      break
    G4 S1
    continue
  if var.height == 12
    set var.v12 = var.r1 + var.r2 + var.r3 - max(var.r1, var.r2, var.r3) - min(var.r1, var.r2, var.r3)
    set var.height = 8
    set var.tries = 0
  else
    set var.v8 = var.r1 + var.r2 + var.r3 - max(var.r1, var.r2, var.r3) - min(var.r1, var.r2, var.r3)
    break
if var.error == "" && var.v8 - var.v12 < 30
  set var.error = "SZP reading rose by only " ^ (var.v8 - var.v12) ^ " from Z12 to Z8 above the bed centre - sensor not responding"

if var.error == ""
  while true
    if iterations >= 3
      set var.error = "bed " ^ var.off ^ " mm off level at the third coarse pass - the corrections do not converge"
      break
    set var.pass = iterations + 1
    G30 P0 X{move.axes[0].min + 50} Y{move.kinematics.tiltCorrection.screwY[0]} Z-99999
    if result != 0
      set var.error = "coarse probe at P0 failed - that corner more than 6 mm high, or no trigger"
      break
    set var.h0 = sensors.probes[0].lastStopHeight - sensors.probes[0].triggerHeight
    G30 P1 X{move.axes[0].min + 50} Y{move.kinematics.tiltCorrection.screwY[1]} Z-99999
    if result != 0
      set var.error = "coarse probe at P1 failed - that corner more than 6 mm high, or no trigger"
      break
    set var.h1 = sensors.probes[0].lastStopHeight - sensors.probes[0].triggerHeight
    G30 P2 X{move.axes[0].max - sensors.probes[0].offsets[0]*2} Y{move.kinematics.tiltCorrection.screwY[2]} Z-99999
    if result != 0
      set var.error = "coarse probe at P2 failed - that corner more than 6 mm high, or no trigger"
      break
    set var.h2 = sensors.probes[0].lastStopHeight - sensors.probes[0].triggerHeight
    G30 P3 X{move.axes[0].max - sensors.probes[0].offsets[0]*2} Y{move.kinematics.tiltCorrection.screwY[3]} Z-99999
    if result != 0
      set var.error = "coarse probe at P3 failed - that corner more than 6 mm high, or no trigger"
      break
    set var.h3 = sensors.probes[0].lastStopHeight - sensors.probes[0].triggerHeight
    set var.mean = (var.h0 + var.h1 + var.h2 + var.h3) / 4
    set var.off = max(abs(var.h0 - var.mean), abs(var.h1 - var.mean), abs(var.h2 - var.mean), abs(var.h3 - var.mean))
    if global.debug
      echo "coarse-level: pass " ^ var.pass ^ " P0 " ^ var.h0 ^ " P1 " ^ var.h1 ^ " P2 " ^ var.h2 ^ " P3 " ^ var.h3 ^ ", largest off their mean " ^ var.off
    if var.pass == 1 && var.off > 1
      ; not a failure, but a sign of the mechanics: align_z_axis.g should leave the bed level
      M118 P0 L1 S{"Warning: bed " ^ var.off ^ " mm off level after align_z_axis - P0 " ^ var.h0 ^ " P1 " ^ var.h1 ^ " P2 " ^ var.h2 ^ " P3 " ^ var.h3 ^ " - check leadscrew and lower stop of the high corner"}
    if var.off <= 0.3
      break
    ; the tilt alone: the heights less their mean, given as Z so that RRF does not probe again
    G30 P0 X{move.axes[0].min + 50} Y{move.kinematics.tiltCorrection.screwY[0]} Z{var.h0 - var.mean}
    G30 P1 X{move.axes[0].min + 50} Y{move.kinematics.tiltCorrection.screwY[1]} Z{var.h1 - var.mean}
    G30 P2 X{move.axes[0].max - sensors.probes[0].offsets[0]*2} Y{move.kinematics.tiltCorrection.screwY[2]} Z{var.h2 - var.mean}
    G30 P3 X{move.axes[0].max - sensors.probes[0].offsets[0]*2} Y{move.kinematics.tiltCorrection.screwY[3]} Z{var.h3 - var.mean} S4
    if result != 0
      set var.error = "coarse levelling refused, a correction above 5 mm (M671 S5) - P0 " ^ var.h0 ^ " P1 " ^ var.h1 ^ " P2 " ^ var.h2 ^ " P3 " ^ var.h3
      break

if var.error != ""
  G91
  G1 Z10 F600                                    ; bed away from the nozzle, wherever it stopped
  G90
  M400
  echo "Error: " ^ var.error
  M99

set global.result = 0
