; tpost0.g
; called after tool 0 has been selected
;

; run /filaments/<filament name>/config.g
M703

var current_tool = 0
var current_extruder = tools[var.current_tool].extruders[0]
var current_filament = move.extruders[var.current_extruder].filament

if fileexists({"0:/filaments/" ^ {var.current_filament } ^ "/config-auto-esteps.g"})
  M98 P{"0:/filaments/" ^ {var.current_filament } ^ "/config-auto-esteps.g"}

var current_esteps = move.extruders[var.current_extruder].stepsPerMm
var validValue = 50 * move.extruders[var.current_extruder].microstepping.value

if var.current_esteps < (var.validValue * 0.8) || var.current_esteps > (var.validValue * 1.2)
  echo "Warning: configured E-Steps of tool " ^ var.current_tool ^ " out of range, please check the configuration. Using Default."
  M92 E{var.validValue}

if fileexists({"0:/filaments/" ^ {var.current_filament } ^ "/config-auto-nle.g"})
  M98 P{"0:/filaments/" ^ {var.current_filament } ^ "/config-auto-nle.g"}

if fileexists({"0:/filaments/" ^ {var.current_filament } ^ "/config-auto-pa.g"})
  M98 P{"0:/filaments/" ^ {var.current_filament } ^ "/config-auto-pa.g"}

; Wait for set temperatures to be reached
if heat.heaters[tools[0].heaters[0]].current < heat.heaters[tools[0].heaters[0]].active
  M116 P0                 ; wait for T0 only if we need to heat up

