M98 P"0:/sys/meltingplot/ensure_safety"

var motor_currents = {move.axes[0].percentCurrent, move.axes[1].percentCurrent, move.axes[3].percentCurrent}

M400                                                    ; wait for all moves to finish
M913 X{880/move.axes[0].current*100}                    ; reduce motor current to 40% of 2200mA = 880mA for homing
M400                                                    ; wait for all moves to finish
M17 X
M400

M569 P50.0 D4
M569 P51.0 D4
M569 P52.0 D2
M569 P53.0 D2
M18 Y U ; disable Y and U
M913 Y0 U0

M569.1 P50.0 E4.0:2.0
M569.1 P51.0 E4.0:2.0
;M569 P51.0 D2

if !exists(global.closed_loop_homing)
  global closed_loop_homing = true
else
  set global.closed_loop_homing = true

G92 X10
G91 G1 X{(move.axes[0].max-move.axes[0].min+10)} F6000
; a driver erro will only stop the driver with the error not the full move
; the X gantry is linked to the Y and U axis and is moving these motors as well
; that is the reason why we set the Y and U axis in open loop mode
G92 X{move.axes[0].max+0.8} ; will report an error of 2 full steps -> we concider 2 additional full steps as stretch in the belt
G90 G1 X{move.axes[0].max}

set global.closed_loop_homing = false

M569 P50.0 D2
M569 P51.0 D2

M18 X ; enable if you want to unsquare the gantry - squaring is done by adjusting Y and U belt tension only!
M400
G4 P500
M17 X ; fall back to full step
M400

G92 X{move.axes[0].max}
M400
G4 P500

M569 P50.0 D4
M569 P51.0 D4
M569 P52.0 D4
M569 P53.0 D4

M569.1 P50.0 E6.0:20.0
M569.1 P51.0 E6.0:20.0
M400                                                              ; wait for all moves to finish
M913 X{var.motor_currents[0]} Y{var.motor_currents[1]} U{var.motor_currents[2]}                               ; restore motor current
M400                                                              ; wait for all moves to finish

M98 P"0:/sys/homey.g"
M98 P"0:/sys/homeu.g"
