M207 S0.8 R0.0 F1500 T800 Z0.05     ; retract
M592 D0 A0 B0.0045                  ; non linear extrusion
M572 D0 S0.1                     	; pressure advance
M92 E821							; set E-Steps for STYX-12 PA12 (300'C)

if fileexists({"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-esteps.g"})
  M98 P{"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-esteps.g"}

if fileexists({"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-nle.g"})
  M98 P{"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-nle.g"}