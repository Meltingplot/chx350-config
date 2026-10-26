; Luvocom 3F PP CF 9928 - user customizations (M572 pressure advance, M207 retract, ...)
M207 S0.8 R0.0 F1800 T1000 Z0.05  ; retract
M572 D0 S0.075                    ; pressure advance 0.6mm nozzle
set global.filament_exhaust_run_on = 600   ; exhaust run-on (s) after a job and after a door opens while Luvocom 3F PP CF 9928 is set up (0 = none)
