; PLA NX2 black matt 0.8mm - user customizations (M572 pressure advance, M207 retract, ...)
M207 S0.4 R0.0 F1250 T1250 Z0.4          ; retraction
M572 D0 S0.0155                          ; pressure advance
M309 P0 S0.03 T0 A0                    ; heater feed forward

set global.filament_max_flow_rate = 35
