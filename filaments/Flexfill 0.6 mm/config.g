M207 S1.8 R0 F2600 T1200 Z0.45      ; retract for 
M592 D0 A-0.0027 B0.007 L0.2        ; non linear extrusion
M572 D0 S0.040                       ; pressure advance 
M92 E850							; E-Steps Flexfill

if fileexists({"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-esteps.g"})
  M98 P{"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-esteps.g"}

if fileexists({"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-nle.g"})
  M98 P{"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-nle.g"}