; homey.g
; called to home the Y axis
;
; The Y carriage rides on the X beam and its hard stop sits on the beam. The beam is rigid only while
; both X motors hold in closed loop; otherwise the stall force of the Y motor drags the beam along
; instead of loading the encoder, and the lag no longer measures "carriage at the stop". X is therefore
; switched to closed loop first - that needs the encoder calibration, not a homed axis. The reference
; taken here is only valid for a square beam, so homex.g calls this file after squaring and
; re-references X afterwards.
;
; The encoder endstop (M574 Y1 S5) triggers when the rotor falls behind the commanded position by the
; first value of M569.1 E, in full steps. At that moment the field is E full steps beyond the rotor and
; the rotor is pressed into the stop with the full stall torque. Switching to closed loop right there
; adopts that pressed position as the reference (SetTargetToCurrentPosition in ClosedLoop.cpp), and
; every later move to the limit rebuilds the belt compression with full PID authority - the bang.
; So: back off, approach slowly (the trigger overshoot beyond E scales with speed), unload exactly
; E full steps with a commanded move, and only then declare the position and switch to closed loop.
; The commanded unload also takes motor_X back, which followed Y into the stall (motor_X = X + Y - U),
; so the beam creep of the stall is undone. No M18/M17 snap: on this kinematics any uncommanded Y motion
; shifts X invisibly, and with the rotor defined by the stop there is nothing to snap to.
;
; The two passes need different margins. The firmware compares the distance commanded since the move
; was armed with the distance the encoder reports (stallEndstopArmed in ClosedLoop.cpp), so E is the
; slip accumulated over the whole move, not the instantaneous following error. Over the full travel at
; F6000 ordinary slip alone reaches two full steps, which triggers the endstop somewhere in mid air:
; the axis is declared homed in the wrong place and only the slow approach notices, because it then
; finds no stop within its 10 mm. The fast pass therefore keeps the running margin of 6 full steps and
; only the 10 mm slow approach - too short to accumulate slip - drops to 2 for a tight, repeatable
; trigger. Both passes are checked by the position the trigger writes, not by the homed flag, which may
; still be set from an earlier homing. A pass that misses its stop is retried instead of accepted, and
; if no attempt works the axis is left unhomed: a wrong reference is worse than a missing one, and the
; callers that home conditionally (homez.g, bed.g) then home it again instead of moving on it.

set global.result = 0

M98 P"0:/sys/meltingplot/ensure_safety"

var motor_current = move.axes[1].percentCurrent
var fullstep = move.axes[1].microstepping.value / move.axes[1].stepsPerMm    ; 0.2 mm at 64 microsteps and 320 steps/mm
var lag_fast = 6.0                                                             ; fast pass: slip over the whole travel must stay below this
var lag_slow = 2.0                                                             ; slow pass: full steps behind the commanded position at the trigger
var clearance = var.fullstep                                                   ; the stop sits this far outside the axis limit

M400                                                    ; wait for all moves to finish
M17 X Y
M569 P50.0 D4                                           ; X holds the beam in closed loop, homed or not
M569 P51.0 D4
M913 Y{800/move.axes[1].current*100}                    ; reduce motor current to 800mA for homing
M569 P52.0 D2

while true
  set global.result = 0
  M569.1 P52.0 E{var.lag_fast, 20.0}                          ; first value = endstop trigger in full steps
  G91 G1 H1 Y{-(move.axes[1].max-move.axes[1].min+10)} F6000   ; fast to the stop
  M400
  if abs(move.axes[1].machinePosition - move.axes[1].min) > 0.01
    M118 P0 S"Error: Y endstop did not trigger"
    set global.result = 1
  else
    G91 G1 Y5 F3000                                           ; back off with a plain move so motor_X follows (never H2: that moves the motor alone)
    M569.1 P52.0 E{var.lag_slow, 4.0}                         ; tighten the trigger for the short approach
    G91 G1 H1 Y-10 F300                                       ; slow approach: lag at the trigger is E within a few hundredths of a full step
    M400
    if abs(move.axes[1].machinePosition - move.axes[1].min) > 0.01
      M118 P0 S"Error: Y endstop did not trigger on the slow approach"
      set global.result = 1
    else
      G91 G1 Y{var.lag_slow * var.fullstep} F300              ; unload: field back on the rotor, force-free contact, beam creep undone
      M400
      G92 Y{move.axes[1].min - var.clearance}                 ; the force-free contact is the reference
      G90 G1 Y{move.axes[1].min} F3000                        ; off the stop, inside the limits
  if global.result == 0
    break
  if iterations >= 2
    M118 P0 S"Error: Y homing failed on all three attempts"
    break
  M118 P0 S"Warning: Y homing - retry"

M569.1 P52.0 E6.0:20.0
M569 P52.0 D4                                           ; adopts the current encoder position, error ~0, no jump
M913 Y{var.motor_current}                               ; restore motor current
M400                                                    ; wait for all moves to finish

if global.result != 0
  M18 Y                                                 ; drop the reference, the axis is not where it claims to be
