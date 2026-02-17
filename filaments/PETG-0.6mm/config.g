M207 S0.80 R0.00 F1000 T840 Z0.25      	; retract for PETG
M592 D0 A0.005 B0.0085        			; non linear extrusion
M572 D0 S0.15							; pressure advance for petg
M92 E834 								; e-step for PET-G

if fileexists({"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-esteps.g"})
  M98 P{"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-esteps.g"}

if fileexists({"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-nle.g"})
  M98 P{"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-nle.g"}