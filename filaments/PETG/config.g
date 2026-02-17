M207 S1.20 R0 F1250 T840 Z0.25      ; retract for PETG
M592 D0 A0.00 B0.0113 L0.2          ; non linear extrusion
M572 D0 S0.145                      ; pressure advance for petg

if fileexists({"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-esteps.g"})
  M98 P{"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-esteps.g"}

if fileexists({"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-nle.g"})
  M98 P{"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-nle.g"}