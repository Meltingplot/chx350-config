M207 S0.6 R0.0083 F1800 T1200 Z0.6         ; retraction
M572 D0 S0.058                          ; pressure advance
M309 P0 S0.03 T6 A0                    ; heater feed forward

M143 H1 S350                               ; set temperature limit for heater 2 to 350C

set global.filament_max_flow_rate = 30
M98 P"0:/sys/meltingplot/load_filament_sensorless_conditionally.g"