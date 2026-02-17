M207 S1.5 R0.0 F2200 T1200 Z0.25   ; retract for PythonFlex
M592 D0 A-0.02 B0.04 L0.2           ; non linear extrusion
M572 D0 S0.05                       ; pressure advance 0.6mm nozzle
M92 E890							; E-Steps

if fileexists({"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-esteps.g"})
  M98 P{"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-esteps.g"}

if fileexists({"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-nle.g"})
  M98 P{"0:/filaments/" ^ {move.extruders[0].filament} ^ "/config-auto-nle.g"}