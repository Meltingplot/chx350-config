if global.debug
  echo "align_z_axis.g"

var motor_current = move.axes[2].percentCurrent
var max_travel = move.axes[2].max - move.axes[2].min + 5 ; max travel + 5mm extra
var max_time = var.max_travel / move.axes[2].speed * 1.1

set global.sensorless_z_homing = true      ; ignore stall events on z-axis

G91                                        ; relative position
M400                                       ; make sure everything has stopped before we reset the motor currents
M913 Z{500/move.axes[2].current*100}       ; reduce motor current to 500mA
M915 Z R0 ; ignore stall events for the next moves
G1 H2 Z5 F600                              ; lower z-axis if it is already stalled
G1 H2 Z-5 F600                             ; raise z-axis to free up speed friction move
M400                                       ; wait for moves to finish
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
G92 Z{move.axes[2].max}
M400
G91 G1 Z-5
M400
G4 P500
M915 Z R2 ; enable stall events again

set global.sensorless_z_homing = false      ; ignore stall events on z-axis

M98 P"0:/sys/meltingplot/ce-declaration/reload-operating-mode.g"
