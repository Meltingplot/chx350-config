; Luvocom 3F PAHT 9936 - user customizations (M572 pressure advance, M207 retract, ...)
M207 S2.9 R0.0 F1800 Z0.05   		; retract
M572 D0 S0.075                      ; pressure advance 0.6mm nozzle

M143 H1 S350                               ; set temperature limit for heater 2 to 350C
set global.filament_exhaust_run_on = 600   ; exhaust run-on (s) after a job and after a door opens while Luvocom 3F PAHT 9936 is set up (0 = none)
