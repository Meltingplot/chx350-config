; tpost0.g
; called after tool 0 has been selected
;

var current_tool = 0
var current_extruder = tools[var.current_tool].extruders[0]
var current_filament = move.extruders[var.current_extruder].filament

; keep filaments/<name>/config.g machine-owned: regenerate it (and auto-migrate any
; user content into config-override.g) before M703 executes it
if var.current_filament != ""
  M98 P"0:/sys/meltingplot/regenerate_filament_config.g" S{var.current_filament}

; run /filaments/<filament name>/config.g
M703

; calibration results are nozzle-specific (config-auto-<what>-<nozzle key>.g) - a PA or
; NLE calibration only ever describes the nozzle it was run with. Profiles predating the
; per-nozzle split are still picked up through the unsuffixed fallback.
; sformat.g returns the key in global.result - read it straight away
M98 P"0:/sys/meltingplot/sformat.g" F{global.nozzle_diameter[var.current_tool]} D2 W0
var suffix = "-" ^ global.result ^ ".g"
var auto = "0:/filaments/" ^ var.current_filament ^ "/config-auto-esteps"
if fileexists(var.auto ^ var.suffix)
  M98 P{var.auto ^ var.suffix}
elif fileexists(var.auto ^ ".g")
  M98 P{var.auto ^ ".g"}

var current_esteps = move.extruders[var.current_extruder].stepsPerMm
var validValue = 50 * move.extruders[var.current_extruder].microstepping.value

if var.current_esteps < (var.validValue * 0.8) || var.current_esteps > (var.validValue * 1.2)
  echo "Warning: configured E-Steps of tool " ^ var.current_tool ^ " out of range, please check the configuration. Using Default."
  M92 E{var.validValue}

set var.auto = "0:/filaments/" ^ var.current_filament ^ "/config-auto-nle"
if fileexists(var.auto ^ var.suffix)
  M98 P{var.auto ^ var.suffix}
elif fileexists(var.auto ^ ".g")
  M98 P{var.auto ^ ".g"}

set var.auto = "0:/filaments/" ^ var.current_filament ^ "/config-auto-pa"
if fileexists(var.auto ^ var.suffix)
  M98 P{var.auto ^ var.suffix}
elif fileexists(var.auto ^ ".g")
  M98 P{var.auto ^ ".g"}

; Wait for set temperatures to be reached
if heat.heaters[tools[0].heaters[0]].current < heat.heaters[tools[0].heaters[0]].active
  M116 P0                 ; wait for T0 only if we need to heat up

