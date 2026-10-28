; NOVAMID-1030-CF10 0.4mm - user customizations (M572 pressure advance, M207 retract, ...)
M207 S0 R0 F1800 Z0.0			    ; retract
M572 D0 S0.075                     ; pressure advance 0.6mm nozzle
set global.filament_exhaust_run_on = 600   ; exhaust run-on (s) after a job and after a door opens while NOVAMID-1030-CF10 0.4mm is set up (0 = none)
