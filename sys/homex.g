set global.result = 0

M98 P"0:/sys/meltingplot/ensure_safety"

var motor_currents = {move.axes[0].percentCurrent, move.axes[1].percentCurrent, move.axes[3].percentCurrent}
M400                                                    ; wait for all moves to finish
M913 X{1200/move.axes[0].current*100}
M17 X

M569.1 P50.0 E1.0:4.0
M569.1 P51.0 E1.0:4.0

M569 P50.0 D2
M569 P51.0 D2

G91 G1 H1 X{(move.axes[0].max-move.axes[0].min+10)} F6000
M584 X50.0                                                ; set drive mapping
G91 G1 H1 X{(move.axes[0].max-move.axes[0].min+10)} F6000
M584 X51.0                                                ; set drive mapping
G91 G1 H1 X{(move.axes[0].max-move.axes[0].min+10)} F6000
M584 X50.0:51.0                                                ; set drive mapping

M569.1 P50.0 E6.0:20.0
M569.1 P51.0 E6.0:20.0

M569 P50.0 D4
M569 P51.0 D4
M913 X{var.motor_currents[0]} Y{var.motor_currents[1]} U{var.motor_currents[2]}                               ; restore motor current
M400                                                              ; wait for all moves to finish

M98 P"0:/sys/homey.g"
M98 P"0:/sys/homeu.g"
