M207 S0.8 R0 F1250 T1250 Z0          ; retraction
M592 D0 A-0.0075 B0.006 L0.2            ; non linear extrusion
M572 D0 S0.035                          ; pressure advance
M92  E746                               ; e-step
M906 E2000                              ; increase motor current
M309 P0 S0.03 T8                        ; heater feed forward

if fileexists({"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-esteps.g"})
  M98 P{"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-esteps.g"}

if fileexists({"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-nle.g"})
  M98 P{"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-nle.g"}