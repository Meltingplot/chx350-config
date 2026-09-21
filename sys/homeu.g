; homeu.g
; called to home the U axis
;
; Mirror image of homey.g at the high end of the beam - see there for the reasoning: X must hold the
; beam in closed loop, the reference is only valid for a square beam, the encoder lag is unloaded with
; a commanded move before the switch to closed loop, there is no M18/M17 snap, the fast pass keeps the
; wide margin because E is slip accumulated over the whole move, and a pass that misses its stop is
; retried rather than accepted.

set global.result = 0

M98 P"0:/sys/meltingplot/ensure_safety"

var motor_current = move.axes[3].percentCurrent
var fullstep = move.axes[3].microstepping.value / move.axes[3].stepsPerMm    ; 0.2 mm at 64 microsteps and 320 steps/mm
var lag_fast = 6.0                                                             ; fast pass: slip over the whole travel must stay below this
var lag_slow = 2.0                                                             ; slow pass: full steps behind the commanded position at the trigger
var clearance = var.fullstep                                                   ; the stop sits this far outside the axis limit

M400                                                    ; wait for all moves to finish
M17 X U
M569 P50.0 D4                                           ; X holds the beam in closed loop, homed or not
M569 P51.0 D4
M913 U{800/move.axes[3].current*100}                    ; reduce motor current to 800mA for homing
M569 P53.0 D2

while true
  set global.result = 0
  M569.1 P53.0 E{var.lag_fast, 20.0}                          ; first value = endstop trigger in full steps
  G91 G1 H1 U{(move.axes[3].max-move.axes[3].min+10)} F6000    ; fast to the stop
  M400
  if abs(move.axes[3].machinePosition - move.axes[3].max) > 0.01
    M118 P0 S"Error: U endstop did not trigger"
    set global.result = 1
  else
    G91 G1 U-5 F3000                                          ; back off with a plain move so motor_X follows (never H2: that moves the motor alone)
    M569.1 P53.0 E{var.lag_slow, 4.0}                         ; tighten the trigger for the short approach
    G91 G1 H1 U10 F300                                        ; slow approach: lag at the trigger is E within a few hundredths of a full step
    M400
    if abs(move.axes[3].machinePosition - move.axes[3].max) > 0.01
      M118 P0 S"Error: U endstop did not trigger on the slow approach"
      set global.result = 1
    else
      G91 G1 U{-var.lag_slow * var.fullstep} F300             ; unload: field back on the rotor, force-free contact, beam creep undone
      M400
      G92 U{move.axes[3].max + var.clearance}                 ; the force-free contact is the reference
      G90 G1 U{move.axes[3].max} F3000                        ; off the stop, inside the limits
  if global.result == 0
    break
  if iterations >= 2
    M118 P0 S"Error: U homing failed on all three attempts"
    break
  M118 P0 S"Warning: U homing - retry"

M569.1 P53.0 E6.0:20.0
M569 P53.0 D4                                           ; adopts the current encoder position, error ~0, no jump
M913 U{var.motor_current}                               ; restore motor current
M400                                                    ; wait for all moves to finish

if global.result != 0
  M18 U                                                 ; drop the reference, the axis is not where it claims to be
