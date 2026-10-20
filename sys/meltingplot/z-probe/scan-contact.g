; z-probe/scan-contact.g
; Finds the height at which the nozzle touches the bed and sets Z = 0 there (G92): the
; automatic replacement of the Z height gauge in macro calibrate_z_height_automatic. It
; cleans the nozzle first - residue at the tip moves the contact - and scans at the bed
; centre, the scanning probe's reading sampled at rest after every step.
;   M98 P"0:/sys/meltingplot/z-probe/scan-contact.g" S<start Z> L<lowest Z>
; S = the start height, above any possible contact in the current Z frame;
; L = the lowest Z the approach may reach: the deepest plausible contact plus elastic margin.
; Without a contact above L the scan aborts there.
; Approach, 0.1 mm steps up: coming closer, the reading rises ever faster. Once the nozzle
; touches, bed and print head deflect elastically, the coil-to-bed distance stops shrinking
; and the rise collapses. Two steps in a row that rise by at most half the steepest rise are
; the contact - a knee as well as a plateau. Measured against the steepest rise, not against
; the step before: the knee spreads over two or three steps, and a rise that fades step by
; step never halves against its predecessor (two cold scans of 2026-10-19 passed the old
; check by 2 and 4 counts; a few less and the bed would have pushed on into the nozzle).
; Back-off, 0.01 mm steps down from there: while the nozzle still presses on the bed the
; reading stays on its plateau. The first step that falls clearly below it, confirmed by the
; next one, is where the nozzle lifts off - that is Z0. Unlike the approach's knee it does
; not depend on how soft the contact is. Approach and back-off must agree within 0.15 mm.
; Why not RRF's touch mode: the SZP board takes three invalid readings in a row as a touch
; (TouchMode::ProcessReading), so a G30 needs a drive current that stays valid down to the
; bed - which is what the calibration is still looking for - and where a touch stops is what
; z-probe/calibrate.g measures against this contact.
; The approach starts with the lowest drive current that reads at S (a higher one fails at a
; distance, M558.2) and raises it whenever the reading turns invalid (999999), repeating the
; last 0.5 mm with the new current - the steepest rise must come from one and the same
; current. The back-off keeps the current; an invalid reading there fails the scan.
; With global.debug every reading is echoed - the curve to look at when a scan fails.
; The drive current and reading offset it leaves set are scan values: the caller
; calibrates both modes afterwards (z-probe/calibrate.g).
; Returns global.result 0 with Z = 0 at the contact, 1 on failure (bed 5 mm lower, Z frame
; unchanged). Expects X, Y, U and Z homed and the nozzle hot.

set global.result = 1                            ; every exit before the datum is set is a failure
if !exists(param.S) || !exists(param.L) || param.L >= param.S
  echo "Error: z-probe/scan-contact.g needs a start height S above the lowest height L"
  M99

; clean at a safe height, like homez.g. clean.g sets 0 once it has cleaned; its own refusals
; (axes not homed, default mode) return without setting anything and leave the 1 above
G90
G1 Z200 F6000
M400
M98 P"0:/sys/meltingplot/nozzle-cleaner/clean.g"
if global.result != 0
  set global.result = 1
  echo "Error: nozzle not cleaned - its contact would be off"
  M99
set global.result = 1
G1 X{move.axes[0].max/2} Y{move.axes[1].max/2} U{move.axes[3].max} F60000
G1 Z20 F6000

var error = ""
M400
M564 S0                                          ; soft limits off: the contact can lie below Z0 of the frame
G1 Z{param.S} F600
M400

; lowest drive current that reads at the start height
var current = 15
while true
  M558.2 K0 S{var.current} R0
  G4 S1                                          ; let the sensor settle on the new current
  if sensors.probes[0].value[0] < 999999
    break
  set var.current = var.current + 1
  if var.current > 31
    set var.error = "no SZP drive current reads at the scan start Z" ^ param.S
    break

; noise of the reading at rest - the thresholds below are multiples of it. The SZP board
; reports its reading every 250 ms (board status, HeatSampleIntervalMillis), so samples
; 250 ms apart are fresh ones. A floor of 3 counts: identical samples prove no quiet sensor.
var noise = 0
if var.error == ""
  var lo = 999999
  var hi = 0
  while iterations < 5
    var r = sensors.probes[0].value[0]
    set var.lo = min(var.lo, var.r)
    set var.hi = max(var.hi, var.r)
    G4 P250
  if var.hi >= 999999 || var.lo <= 0
    set var.error = "SZP reading unstable at the scan start"
  else
    set var.noise = max(var.hi - var.lo, 3)

; approach in 0.1 mm steps until the rise collapses
var step = 0.1
var z = param.S
var z_knee = 1000                                ; contact found by the approach, 1000 = none yet
if var.error == ""
  var have_prev = false                          ; is there a reading at the step before, with this current?
  var prev = 0                                   ; reading at the step before
  var dmax = 0                                   ; steepest rise since the last drive current change
  var flat_z = 1000                              ; start of a step whose rise collapsed, 1000 = none
  var flat_d = 0                                 ; rise of that step
  var alive = false                              ; has the reading proven that it responds?
  var z_ref = 0                                  ; where the current drive current took its first reading
  var v_ref = 0                                  ; and that reading
  while true
    if iterations > 400
      set var.error = "the approach did not end"
      break
    M400
    G4 P400                                      ; at rest, and one board status after the move
    var sum = 0
    var valid = true
    while iterations < 3
      var r = sensors.probes[0].value[0]
      if var.r >= 999999 || var.r <= 0
        set var.valid = false
        break
      set var.sum = var.sum + var.r
      G4 P250
    if !var.valid
      ; too close for this drive current: raise it and repeat the last 0.5 mm with it
      set var.current = var.current + 1
      if var.current > 31
        set var.error = "no SZP drive current reads at Z" ^ var.z
        break
      M558.2 K0 S{var.current} R0
      set var.z = min(var.z + 0.5, param.S)
      G1 Z{var.z} F600
      M400
      G4 S1                                      ; let the sensor settle on the new current
      set var.have_prev = false
      set var.dmax = 0
      set var.flat_z = 1000
      continue
    var v = var.sum / 3
    if global.debug
      echo "scan-contact: Z " ^ var.z ^ " reading " ^ var.v ^ " current " ^ var.current
    if !var.have_prev
      set var.have_prev = true
      set var.z_ref = var.z
      set var.v_ref = var.v
    else
      var d = var.v - var.prev
      ; The approach is convex - every step rises more than the one before - so a rise down to
      ; half the steepest one is the nozzle on the bed. Biased towards sensitive: a contact
      ; taken in the air fails the back-off, a contact missed pushes the bed on into the nozzle.
      var collapsed = var.dmax >= {10 * var.noise} && var.d <= {0.5 * var.dmax}
      if var.collapsed && var.flat_z < 1000
        ; second collapsed step in a row: the nozzle touches. In the first one the bed rose at
        ; the approach rate dmax for a fraction f of the step and at the contact rate d for the
        ; rest, flat_d = f * dmax + (1 - f) * d - the knee lies f steps below its start.
        set var.z_knee = {var.flat_z - min(max((var.flat_d - var.d) / (var.dmax - var.d), 0), 1) * var.step}
        break
      if var.collapsed
        set var.flat_z = var.z + var.step
        set var.flat_d = var.d
      elif var.d < {-3 * var.noise} && var.dmax < {10 * var.noise}
        ; falling without a steep approach before it - not what a nozzle coming closer does
        set var.error = "the SZP reading falls at Z" ^ var.z ^ " without an approach before it"
        break
      else
        ; still approaching - or the collapsed step was noise and the reading rises again
        set var.flat_z = 1000
        set var.dmax = max(var.dmax, var.d)
      ; before the contact: a reading that does not rise means a dead or frozen sensor, and
      ; the approach would push the bed into the nozzle down to L
      if !var.alive && var.z_ref - var.z >= 1.5
        if var.v - var.v_ref < {10 * var.noise}
          set var.error = "the SZP reading rose by only " ^ (var.v - var.v_ref) ^ " over 1.5 mm - sensor not responding"
          break
        set var.alive = true
    set var.prev = var.v
    if var.z - var.step < param.L - 0.001
      set var.error = "no contact found down to Z" ^ param.L
      break
    set var.z = var.z - var.step
    G1 Z{var.z} F300

; back off in 0.01 mm steps until the reading falls below its plateau - the nozzle lifts off.
; A fall of 3 x noise: in contact the reading holds or still rises (the deflection relaxes),
; off the bed it falls by about a tenth of the steepest approach rise per step
var fine = 0.01
var z_contact = 1000                             ; the lift-off, 1000 = none yet
if var.error == ""
  var vmax = 0                                   ; top of the plateau so far
  var z_drop = 1000                              ; first step below it, 1000 = none
  G4 S1                                          ; settle in the deepest position
  while true
    if iterations > 100
      set var.error = "the back-off did not end"
      break
    M400
    G4 P400
    var sum = 0
    var valid = true
    while iterations < 3
      var r = sensors.probes[0].value[0]
      if var.r >= 999999 || var.r <= 0
        set var.valid = false
        break
      set var.sum = var.sum + var.r
      G4 P250
    if !var.valid
      set var.error = "SZP reading invalid at Z" ^ var.z ^ " while backing off"
      break
    var v = var.sum / 3
    if global.debug
      echo "scan-contact: back-off Z " ^ var.z ^ " reading " ^ var.v
    if var.v > var.vmax
      set var.vmax = var.v                       ; still on the bed
      set var.z_drop = 1000
    elif var.v < {var.vmax - 3 * var.noise}
      if var.z_drop < 1000
        set var.z_contact = var.z_drop           ; confirmed: the nozzle lifted off at the first of the two
        break
      set var.z_drop = var.z
    else
      set var.z_drop = 1000                      ; back on the plateau - that drop was noise
    if var.z + var.fine > var.z_knee + 0.2
      set var.error = "no lift-off found up to 0.2 mm above the approach contact Z" ^ var.z_knee
      break
    set var.z = var.z + var.fine
    G1 Z{var.z} F300

if var.error == "" && abs(var.z_contact - var.z_knee) > 0.15
  set var.error = "approach (Z" ^ var.z_knee ^ ") and back-off (Z" ^ var.z_contact ^ ") disagree"

M400
if var.error != ""
  G91
  G1 Z5 F600                                     ; bed away from the nozzle, wherever the scan stopped
  G90
  M400
  M564 S1
  echo "Error: " ^ var.error
  M99

echo "scan-contact: contact at Z" ^ var.z_contact ^ " (approach Z" ^ var.z_knee ^ ", drive current " ^ var.current ^ ", noise " ^ var.noise ^ ")"
G1 Z{var.z_contact + 1} F600
M400
G92 Z{move.axes[2].userPosition - var.z_contact} ; Z = 0 where the nozzle lifts off the bed
M564 S1                                          ; soft limits on again
set global.result = 0
