M207 S2.9 R0.0 F1800 Z0.05   		; retract
M572 D0 S0.075                      ; pressure advance 0.6mm nozzle

M143 H1 S350                               ; set temperature limit for heater 2 to 350C

M98 P"0:/sys/meltingplot/load_filament_sensorless_conditionally.g"

