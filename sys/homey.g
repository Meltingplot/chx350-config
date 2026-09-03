; homey.g
; called to home the Y axis
;

set global.result = 0

M98 P"0:/sys/meltingplot/ensure_safety"

var motor_current = move.axes[1].percentCurrent

M400                                                    ; wait for all moves to finish
M913 Y{800/move.axes[1].current*100}                    ; reduce motor current to 800mA for homing
M400                                                    ; wait for all moves to finish
M17 Y
M400

M569.1 P52.0 E4.0:2.0
M569 P52.0 D4

if !exists(global.closed_loop_homing)
  global closed_loop_homing = true
else
  set global.closed_loop_homing = true

G91 G1 H2 Y{-(move.axes[1].max-move.axes[1].min+10)} F6000
M400
G4 P500
set global.closed_loop_homing = false

G92 Y{move.axes[1].min-0.8}
G90 G1 Y0
M569 P52.0 D2
M18 Y
M400
G4 P500
M17 Y ; fall back to full step
G92 Y{move.axes[1].min}
M569 P52.0 D4
M569.1 P52.0 E6.0:20.0
M400                                                              ; wait for all moves to finish
M913 Y{var.motor_current}                                         ; restore motor current
M400                                                              ; wait for all moves to finish
