M572 D0 S0.1                        ; set pressure advance
M592 D0 A0.00 B0.0112 L0.2          ; non linear extrusion
M207 S0.40 R0.0 F2100 T840 Z0.25    ; retract for ABS

if fileexists({"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-esteps.g"})
  M98 P{"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-esteps.g"}

if fileexists({"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-nle.g"})
  M98 P{"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-nle.g"}