; Meltingplot PA6 CF HT 0.8mm - user customizations (M572 pressure advance, M207 retract, ...)
M207 S0.8 R0 F1250 T1250 Z0          ; retraction
M572 D0 S0.035                          ; pressure advance
M309 P0 S0.03 T8                        ; heater feed forward

M143 H1 S350                               ; set temperature limit for heater 2 to 350C
set global.filament_exhaust_run_on = 600   ; exhaust run-on (s) after a job and after a door opens while Meltingplot PA6 CF HT 0.8mm is set up (0 = none)
