M207 S0.8 R0 F1250 T1250 Z0          ; retraction
M572 D0 S0.035                          ; pressure advance
M309 P0 S0.03 T8                        ; heater feed forward

M143 H1 S350                               ; set temperature limit for heater 2 to 350C

M98 P"0:/sys/meltingplot/load_filament_sensorless_conditionally.g"

