; homeu.g
; called to home the U axis
;
; Hmin = full_steps_per_rev * rated_current * actual_current/(sqrt(2) * pi * rated_holding_torque)
; where
; full_steps_per_rev = 200 steps/rev
; rated_current = 2.5A
; actual_current = 0.880A
; rated_holding_torque = 0.55Nm
; Hmin = 200 * 2.5 * 0.880 / (sqrt(2) * pi * 0.55) = 180.327 steps / sec
; 200 * 2.5 * 0.880 / 2.4435856159871014358587345445334 = 180.327 steps / sec
; So we set H to 185 to be sure of hitting the endstop
; 1 rev is 40mm so 185 steps/sec is 185/200 * 40 = 37 mm/sec * 60 = 2220 mm/min

set global.result = 0

M98 P"0:/sys/meltingplot/ensure_safety"

var motor_current = move.axes[3].percentCurrent

M400                                                    ; wait for all moves to finish
M913 U{800/move.axes[3].current*100}
M17 X U
M569.1 P53.0 E1.0:4.0
M569 P53.0 D2

G91 G1 H1 U{(move.axes[3].max-move.axes[3].min+10)} F6000
M400
M18 U
M400
M17 U
G92 U{move.axes[3].max}
M569.1 P53.0 E6.0:20.0
M569 P53.0 D4
M913 U{var.motor_current}
M400                                                              ; wait for all moves to finish
