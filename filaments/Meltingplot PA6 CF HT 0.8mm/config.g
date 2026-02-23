M207 S0.8 R0 F1250 T1250 Z0          ; retraction
M572 D0 S0.035                          ; pressure advance
M906 E2000                              ; increase motor current
M309 P0 S0.03 T8                        ; heater feed forward

M98 P"0:/sys/meltingplot/load_filament_sensorless_conditionally.g"

