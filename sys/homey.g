; homey.g
; called to home the Y axis
;

set global.result = 0

M98 P"0:/sys/meltingplot/ensure_safety"

var motor_current = move.axes[1].percentCurrent

M400                                                    ; wait for all moves to finish
M913 Y{800/move.axes[1].current*100}
M17 X Y
M569.1 P52.0 E1.0:4.0
M569 P52.0 D2

G91 G1 H1 Y{-(move.axes[1].max-move.axes[1].min+10)} F6000
M400
M18 Y
M400
M17 Y
G92 Y{move.axes[1].min}
M569.1 P52.0 E6.0:20.0
M569 P52.0 D4
M913 Y{var.motor_current}
M400                                                              ; wait for all moves to finish
