; tpost0.g
; called after tool 0 has been selected
;

; run /filaments/<filament name>/config.g
M703

var current_tool = 0
var current_filament = move.extruders[var.current_tool].filament

if fileexists({"0:/filaments/" ^ {var.current_filament } ^ "/config-auto-esteps.g"})
  M98 P{"0:/filaments/" ^ {var.current_filament } ^ "/config-auto-esteps.g"}

if fileexists({"0:/filaments/" ^ {var.current_filament } ^ "/config-auto-nle.g"})
  M98 P{"0:/filaments/" ^ {var.current_filament } ^ "/config-auto-nle.g"}

; Wait for set temperatures to be reached
if heat.heaters[tools[0].heaters[0]].current < heat.heaters[tools[0].heaters[0]].active
  M116 P0                 ; wait for T0 only if we need to heat up
