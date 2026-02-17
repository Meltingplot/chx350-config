M207 S0.85 R0 F1600 T1200 Z0.25      ; retract for 
M592 D0 A-0.015 B0.015 L0.2        	; non linear extrusion
M572 D0 S0.02                       ; pressure advance 
M92 E850							; E-Steps Flexfill

if fileexists({"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-esteps.g"})
  M98 P{"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-esteps.g"}

if fileexists({"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-nle.g"})
  M98 P{"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-nle.g"}