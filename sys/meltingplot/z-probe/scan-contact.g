; z-probe/scan-contact.g
; Finds the height at which the nozzle touches the bed and sets Z = 0 there (G92): the
; automatic replacement of the Z height gauge in macro calibration/z-height. The bed moves
; up under the nozzle in small steps while the scanning probe's reading is sampled at rest.
; Coming closer, the reading rises ever faster; once the nozzle touches, bed and print head
; deflect elastically, the coil-to-bed distance stops shrinking and the reading stops rising
; or falls. The contact lies at that knee.
;   M98 P"0:/sys/meltingplot/z-probe/scan-contact.g" S<start Z> L<lowest Z>
; S = the start height, above any possible contact in the current Z frame;
; L = the lowest Z the scan may reach: the deepest plausible contact plus elastic margin.
; Without a knee above L there is no contact in the window, and the scan aborts there.
; RRF's touch mode cannot find the contact on its own: the SZP board takes three invalid
; readings in a row as a touch (TouchMode::ProcessReading), so a G30 needs a drive current
; that stays valid down to the bed - which is what the calibration is still looking for.
; The scan starts with the lowest drive current that reads at S (a higher one fails at a
; distance, M558.2) and raises it whenever the reading turns invalid (999999), repeating
; the last 0.5 mm with the new current - the knee needs the slope of one and the same one.
; A first pass in 0.1 mm steps finds the contact, a second in 0.05 mm steps from 0.3 mm
; above it repeats it; the two must agree. Past the contact the bed rises by at most two
; steps (0.2 mm, then 0.1 mm), elastically. With global.debug every reading is echoed - the
; curve to look at when a scan fails.
; The drive current and reading offset it leaves set are scan values: the caller
; calibrates both modes afterwards.
; Returns global.result 0 with Z = 0 at the contact, 1 on failure (bed 5 mm lower, Z frame
; unchanged). Expects X, Y, U and Z homed and the nozzle hot and clean over the bed.

set global.result = 1                            ; every exit before the datum is set is a failure
if !exists(param.S) || !exists(param.L) || param.L >= param.S
  echo "Error: z-probe/scan-contact.g needs a start height S above the lowest height L"
  M99

var error = ""
M400
M564 S0                                          ; soft limits off: the contact can lie below Z0 of the frame
G90
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

var z_first = 0                                  ; contact found by the first pass
var z_contact = 0                                ; contact found by the current pass
var pass = 0
while var.error == "" && var.pass < 2
  var step = (var.pass == 0) ? 0.1 : 0.05
  var top = (var.pass == 0) ? param.S : var.z_first + 0.3
  var lowest = (var.pass == 0) ? param.L : max(param.L, var.z_first - 0.3)
  var z = var.top
  G1 Z{var.z} F600
  M400
  G4 S1                                          ; settle - the drive current may have just changed
  var have_prev = false                          ; is there a reading at the step before, with this current?
  var prev = 0                                   ; reading at the step before
  var s = 0                                      ; rise of the last approach step
  var dmax = 0                                   ; largest rise since the last drive current change
  var flat_z = 1000                              ; start of a step whose rise collapsed, 1000 = none
  var flat_d = 0                                 ; rise of that step
  var alive = (var.pass != 0)                    ; the first pass proves first that the reading responds
  var z_ref = 0                                  ; where the current drive current took its first reading
  var v_ref = 0                                  ; and that reading
  while true
    if iterations > 400
      set var.error = "the scan did not end"
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
      set var.z = min(var.z + 0.5, var.top)
      G1 Z{var.z} F600
      M400
      G4 S1                                      ; let the sensor settle on the new current
      set var.have_prev = false
      set var.s = 0
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
      ; The approach is convex - every step rises more than the one before - so a rise that
      ; halves is the contact. Biased towards sensitive: a knee taken in the air only fails the
      ; second pass, a knee missed pushes the bed on into the nozzle.
      if var.flat_z < 1000 && var.d <= {0.5 * var.s}
        ; second collapsed step in a row: the nozzle touches. In the first one the bed rose at
        ; the approach rate s for a fraction f of the step and at the contact rate d for the
        ; rest, flat_d = f * s + (1 - f) * d - the contact lies f steps below its start.
        set var.z_contact = {var.flat_z - min(max((var.flat_d - var.d) / (var.s - var.d), 0), 1) * var.step}
        break
      if var.flat_z >= 1000 && var.dmax >= {10 * var.noise} && var.s >= {0.6 * var.dmax} && var.d <= {0.5 * var.s}
        ; the rise collapsed right after a steep approach: a contact, if the next step confirms it
        set var.flat_z = var.z + var.step
        set var.flat_d = var.d
      elif var.d < {-3 * var.noise} && var.dmax < {10 * var.noise}
        ; falling without a steep approach before it - not what a nozzle coming closer does
        set var.error = "the SZP reading falls at Z" ^ var.z ^ " without an approach before it"
        break
      else
        ; still approaching - or the collapsed step was noise and the reading rises again
        set var.flat_z = 1000
        set var.s = var.d
        set var.dmax = max(var.dmax, var.d)
      ; before the contact window: a reading that does not rise means a dead or frozen sensor,
      ; and the scan would push the bed into the nozzle down to L
      if !var.alive && var.z_ref - var.z >= 1.5
        if var.v - var.v_ref < {10 * var.noise}
          set var.error = "the SZP reading rose by only " ^ (var.v - var.v_ref) ^ " over 1.5 mm - sensor not responding"
          break
        set var.alive = true
    set var.prev = var.v
    if var.z - var.step < var.lowest - 0.001
      set var.error = "no contact found down to Z" ^ var.lowest
      break
    set var.z = var.z - var.step
    G1 Z{var.z} F300
  if var.error != ""
    break
  echo "scan-contact: pass " ^ (var.pass + 1) ^ " contact at Z" ^ var.z_contact ^ " (drive current " ^ var.current ^ ", noise " ^ var.noise ^ ")"
  if var.pass == 0
    set var.z_first = var.z_contact
  elif abs(var.z_contact - var.z_first) > 0.15
    set var.error = "contact not repeatable: Z" ^ var.z_first ^ " and Z" ^ var.z_contact
  G1 Z{var.z_contact + 0.3} F300                ; off the bed before anything else
  set var.pass = var.pass + 1

M400
if var.error != ""
  G91
  G1 Z5 F600                                     ; bed away from the nozzle, wherever the scan stopped
  G90
  M400
  M564 S1
  echo "Error: " ^ var.error
  M99

G1 Z{var.z_contact + 1} F600
M400
G92 Z{move.axes[2].userPosition - var.z_contact} ; Z = 0 where the nozzle touches the bed
M564 S1                                          ; soft limits on again
set global.result = 0
