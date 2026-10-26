; STYX-12 0.6mm - user customizations (M572 pressure advance, M207 retract, ...)
M207 S0.8 R0.0 F1500 T800 Z0.05     ; retract
M572 D0 S0.1                     	; pressure advance
set global.filament_exhaust_run_on = 600   ; exhaust run-on (s) after a job and after a door opens while STYX-12 0.6mm is set up (0 = none)
