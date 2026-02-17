M207 S0.45 R0 F1250 T600 Z0.25      ; retract for Greentec Pro
M592 D0 A-0.01 B0.0026 L0.2        ; non linear extrusion
M572 D0 S0.005                       ; pressure advance 0.6mm nozzle
M92 E852						; E-Steps

if fileexists({"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-esteps.g"})
  M98 P{"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-esteps.g"}

if fileexists({"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-nle.g"})
  M98 P{"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-nle.g"}
