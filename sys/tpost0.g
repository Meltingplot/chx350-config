; tpost0.g
; called after tool 0 has been selected
;

var current_tool = 0
var current_extruder = tools[var.current_tool].extruders[0]
var current_filament = move.extruders[var.current_extruder].filament

; keep filaments/<name>/config.g machine-owned: regenerate it (and auto-migrate any
; user content into config-override.g) before M703 executes it
if var.current_filament != ""
  M98 P"0:/sys/meltingplot/filament-profile/regenerate.g" S{var.current_filament}

; run /filaments/<filament name>/config.g
M703

; calibration results are specific to the filament diameter and the nozzle
; (config-auto-<what>-<filament>-<nozzle>.g, key from filament-profile/calibration-key.g) - a PA, NLE or
; e-steps calibration only ever describes the pair it was run with. Older files (nozzle
; key only, or unsuffixed) are picked up by the fallback chain in filament-profile/find-calibration-file.g,
; which hands the resolved path back in global.result - read it straight away.
var auto = ""
if var.current_filament != ""
  M98 P"0:/sys/meltingplot/filament-profile/find-calibration-file.g" S{var.current_filament} F"config-auto-esteps" T{var.current_tool}
  set var.auto = global.result
if var.auto != ""
  M98 P{var.auto}

var current_esteps = move.extruders[var.current_extruder].stepsPerMm
var validValue = {50 * move.extruders[var.current_extruder].microstepping.value}

if var.current_esteps < {var.validValue * 0.8} || var.current_esteps > {var.validValue * 1.2}
  echo "Warning: configured E-Steps of tool " ^ var.current_tool ^ " out of range, please check the configuration. Using Default."
  M92 E{var.validValue}

set var.auto = ""
if var.current_filament != ""
  M98 P"0:/sys/meltingplot/filament-profile/find-calibration-file.g" S{var.current_filament} F"config-auto-nle" T{var.current_tool}
  set var.auto = global.result
if var.auto != ""
  M98 P{var.auto}

set var.auto = ""
if var.current_filament != ""
  M98 P"0:/sys/meltingplot/filament-profile/find-calibration-file.g" S{var.current_filament} F"config-auto-pa" T{var.current_tool}
  set var.auto = global.result
if var.auto != ""
  M98 P{var.auto}

; Wait for set temperatures to be reached
if heat.heaters[tools[0].heaters[0]].current < heat.heaters[tools[0].heaters[0]].active
  M116 P0                 ; wait for T0 only if we need to heat up

