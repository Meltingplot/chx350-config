; ABS - user customizations (M572 pressure advance, M207 retract, ...)
M572 D0 S0.1                        ; set pressure advance
M207 S0.40 R0.0 F2100 T840 Z0.25    ; retract for ABS
set global.filament_exhaust_run_on = 600   ; exhaust run-on (s) after a door opens while ABS is set up (0 = none)
