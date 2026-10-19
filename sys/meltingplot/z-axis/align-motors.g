;M98 P"0:/sys/meltingplot/ce-declaration/doors/wait-closed.g" ; this is moved to calling macro
if global.debug
  echo "z-axis/align-motors.g"

var motor_current = move.axes[2].percentCurrent
; Z of the stop in the frame of the nozzle contact (globals, z_lower_stop). Every move until the
; touch probe relies on it: above max + 10 the bed could hit the nozzle on its way to the
; probe's start at Z12, below max the contact lies out of the probe's reach. Read and checked
; before anything moves - a non-numeric value from a broken global-override.g throws here, not
; after sensorless_z_homing is set.
var z_stop = global.z_lower_stop
if var.z_stop < move.axes[2].max || var.z_stop > move.axes[2].max + 10
  M118 P0 L1 S{"Warning: z_lower_stop " ^ var.z_stop ^ " outside " ^ move.axes[2].max ^ ".." ^ (move.axes[2].max + 10) ^ " - aligned Z set to the axis max, homing may not reach the bed"}
  set var.z_stop = move.axes[2].max
var max_travel = var.z_stop - move.axes[2].min + 5 ; full travel + 5mm extra - from Z0 the stop is z_stop away, not M208's max
var max_time = {var.max_travel / move.axes[2].speed * 1.1}

; A stall move starts only with the Z stall watchdog disarmed: trigger5.g disarms the last Z
; homing up to z_motor_stall_time_max + 1 s after its first stall, and stalls before that would
; count against its complete flag. After 40 s T5 has disarmed or halted, so a deadline still
; set means the watchdog does not work - halt rather than drive the motors into their stops.
while global.z_motor_stall_deadline != 0
  if iterations >= 400
    echo "Error: Z stall watchdog still armed after 40 s - machine halt!"
    M112
  G4 P100

set global.sensorless_z_homing = 0x55555555  ; expected Z stalls (hardened true pattern, see globals) - cleared at the end of this file

G91                                        ; relative position
M400                                       ; make sure everything has stopped before we reset the motor currents
M913 Z{500/move.axes[2].current*100}       ; reduce motor current to 500mA - a motor that reaches its stop skips instead of pressing
M915 Z R0 ; ignore stall events for the next moves
G1 H2 Z5 F600                              ; lower z-axis if it is already stalled
M400
; free all motors at full current: the driver updates its stall bit only on full steps, so a
; lift at 500 mA can end with the bit still set, and a motor that starts the G1 H1 below with
; it set stops at once and never reaches its stop (Duet wiki, "Stall detection")
M913 Z{var.motor_current}
G1 H2 Z-5 F600                             ; raise z-axis to free up speed friction move
M400                                       ; wait for moves to finish
M913 Z{500/move.axes[2].current*100}       ; back to 500mA for the stall move
G4 P500
M915 Z R2 ; enable stall events again

G1 H1 Z{var.max_travel} F2000              ; lower z axis

M400                                       ; wait for moves to finish
M915 Z R0                                  ; ignore stall events for the next moves
M913 Z{250/move.axes[2].current*100}       ; further reduce motor current
G91 G1 Z-1                                 ; free up the tension in the mounting springs
M18 Z                                      ; disbale z-motors -> let it jump back to full steps
M400
G4 S1
M913 Z{var.motor_current}                  ; restore motor current
M17 Z ; enable Motor
; Z of this position in the frame of the nozzle contact: the CAD nominal travel (globals,
; z_lower_stop), not M208's max - that keeps the bed 5 mm off the stop once the datum is
; probed. Set to the max, the contact would lie 5 mm below Z0, out of reach of homez.g's
; touch probe (it goes no deeper than Z min - dive height + touch H = Z-2.1).
G92 Z{var.z_stop}
M400
G90 G1 Z{move.axes[2].max}                 ; off the stop, onto the soft limit
M400
G4 P500
M915 Z R2 ; enable stall events again

set global.sensorless_z_homing = 0xAAAAAAAA  ; a Z stall is an E-stop again

M98 P"0:/sys/meltingplot/ce-declaration/reload-operating-mode.g"

; aligned - set after the mode reload, as the last statement: its automatic.g runs M703 while
; a tool is selected, and the profile's config.g leaves a path in global.result
; (filament-profile/find-calibration-file.g). calibration/z-height read that string through
; calibration/align-z-axis, compared it with 0 and stopped (2026-10-19).
set global.result = 0
