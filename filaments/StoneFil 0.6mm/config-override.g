; StoneFil 0.6mm - user customizations (M572 pressure advance, M207 retract, ...)
M207 S0.65 R0 F1000 T600 Z0.25      ; retract for StoneFil
M572 D0 S0.11                       ; pressure advance 0.6mm nozzle
set global.filament_exhaust_run_on = 600   ; exhaust run-on (s) after a job and after a door opens while StoneFil 0.6mm is set up (0 = none)
