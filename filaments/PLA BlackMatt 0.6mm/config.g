M207 S1.0 R0.0 F2400 T900 Z0.05 ; retract for PLA+
M572 D0 S0.07 ; set pressure advance
M592 D0 A0.0029 B0.0014 L0.2 ; non linear extrusion
M92  E817						; E-Step PLA

if fileexists({"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-esteps.g"})
  M98 P{"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-esteps.g"}

if fileexists({"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-nle.g"})
  M98 P{"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-nle.g"}