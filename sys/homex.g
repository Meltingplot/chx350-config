; homex.g
; called to home the X axis - and, because squaring the beam shifts the Y and U references, Y and U too
;
; The beam is driven by two motors (50.0, 51.0). Squaring it racks one end against the other, which
; pulls the Y and U belts through and moves the position of their stops relative to their motors, so a
; Y or U reference taken before squaring is worthless afterwards. Hence the order:
;   1. Y and U are switched to closed loop and only held, not homed: the X belt runs through both
;      carriages (motor_X = X + Y - U), so an X stall would drag an open-loop carriage along.
;   2. Square the beam: each X motor alone against its stop, then both together (M574 X2 S5 stops both
;      motors on the first trigger, hence the single-motor passes). The lag is unloaded so the beam is
;      held force-free, then it holds in closed loop at full current while Y and U home against it.
;   3. Home Y, then U (see homey.g for the two-pass/unload scheme and the reasoning).
;   4. Re-reference X. The beam is still at its stop, so a short slow pass suffices. It is needed because
;      each Y/U homing leaves X off by the trigger latency residual: that residual lag is absorbed into the
;      Y/U coordinate at the switch to closed loop while the beam physically crept by the same amount.
; A lone G28 X must therefore never skip Y and U.

set global.result = 0

M98 P"0:/sys/meltingplot/ensure_safety"

var motor_current = move.axes[0].percentCurrent
var fullstep = move.axes[0].microstepping.value / move.axes[0].stepsPerMm    ; 0.2 mm at 64 microsteps and 320 steps/mm
var lag = 2.0                                                                  ; endstop trigger, full steps behind the commanded position (first value of M569.1 E)
var clearance = var.fullstep                                                   ; the stop sits this far outside the axis limit
var travel = move.axes[0].max - move.axes[0].min + 10

M400                                                    ; wait for all moves to finish
M17 X Y U
M569 P52.0 D4                                           ; 1. Y and U hold their carriages in closed loop, homed or not
M569 P53.0 D4
M913 X{1200/move.axes[0].current*100}                   ; reduce motor current to 1200mA for homing

M569.1 P50.0 E{var.lag, 4.0}                          ; first value = endstop trigger in full steps
M569.1 P51.0 E{var.lag, 4.0}
M569 P50.0 D2
M569 P51.0 D2

; 2. square the beam
M584 X50.0                                              ; motor 50 alone against its stop
G91 G1 H1 X{var.travel} F6000
M584 X51.0                                              ; motor 51 alone against its stop
G91 G1 H1 X{var.travel} F6000
M584 X50.0:51.0                                         ; both together
G91 G1 H1 X{var.travel} F6000
M400
if move.axes[0].homed == false
  M118 P0 S"Error: X endstop did not trigger"
  set global.result = 1
else
  G91 G1 X{-var.lag * var.fullstep} F300                ; unload so the beam is held force-free, not pressed into the stop
  M400
  M569 P50.0 D4                                         ; hold the square beam in closed loop at full current
  M569 P51.0 D4
  M913 X{var.motor_current}

  ; 3. home Y and U against the square beam
  M98 P"0:/sys/homey.g"
  var yu_result = global.result
  M98 P"0:/sys/homeu.g"
  if global.result == 0
    set global.result = var.yu_result

  ; 4. re-reference X, the beam is still at its stop
  M913 X{1200/move.axes[0].current*100}
  M569 P50.0 D2
  M569 P51.0 D2
  G91 G1 X-5 F3000                                      ; back off with a plain move
  G91 G1 H1 X10 F300                                    ; slow approach: lag at the trigger is E within a few hundredths of a full step
  M400
  if abs(move.axes[0].machinePosition - move.axes[0].max) > 0.01
    M118 P0 S"Error: X endstop did not trigger on the slow approach"
    set global.result = 1
  else
    G91 G1 X{-var.lag * var.fullstep} F300              ; unload: fields back on the rotors, force-free contact
    M400
    G92 X{move.axes[0].max + var.clearance}             ; the force-free contact is the reference
    G90 G1 X{move.axes[0].max} F3000                    ; off the stop, inside the limits

M569.1 P50.0 E6.0:20.0
M569.1 P51.0 E6.0:20.0
M569 P50.0 D4                                           ; adopts the current encoder position, error ~0, no jump
M569 P51.0 D4
M913 X{var.motor_current}                               ; restore motor current
M400                                                    ; wait for all moves to finish
