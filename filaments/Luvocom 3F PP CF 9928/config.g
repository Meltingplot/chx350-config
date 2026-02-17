M207 S0.8 R0.0 F1800 T1000 Z0.05  ; retract
M592 D0 A-0.024 B0.0435 L0.2      ; non linear extrusion
M572 D0 S0.075                    ; pressure advance 0.6mm nozzle
M92 E878                          ; E-Steps

if fileexists({"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-esteps.g"})
  M98 P{"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-esteps.g"}

if fileexists({"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-nle.g"})
  M98 P{"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-nle.g"}