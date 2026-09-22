; calibration_key.g
; Builds the key every filament-profile file that depends on the installed hardware is
; named after: "<filament diameter>-<nozzle diameter>", both with two decimals of fixed
; width, e.g. "2.85-0.40" or "1.75-0.60" (filament first, so a directory listing groups
; the 2.85 and the 1.75 files). Used by config-auto-esteps-<key>.g, config-auto-nle-<key>.g,
; config-auto-pa-<key>.g and nozzle-<key>.g: e-steps, NLE, PA, retraction and heater
; feedforward all depend on the filament diameter as much as on the nozzle - a 1.75 mm
; extruder has different gears, and at the same filament speed 2.85 mm moves 2.65 times
; the volume - so a result only ever describes the pair it was measured with.
;   M98 P"0:/sys/meltingplot/calibration_key.g" T0
; T<tool> is optional and defaults to the current tool. The key is handed back in
; global.result (RRF macros cannot return a value) - read it on the next line.
; Writers (the three calibration macros, create_nozzle_config.g) build file names from
; this key; readers go through find_calibration_file.g, which adds the fallback chain
; for files predating the filament suffix (and duplicates this format for it).
; Never concatenate the raw floats instead: RRF keeps the decimal places a value was
; written with (0.4 -> "0.4", 0.4000 -> "0.4000", computed -> "0.4000000"), see globals.

if global.debug
  echo "calibration_key.g"

var tool = exists(param.T) ? ((param.T == 1) ? 1 : 0) : min(max(state.currentTool, 0), 1)

; sformat.g returns in global.result - read it straight away, each time
M98 P"0:/sys/meltingplot/sformat.g" F{global.filament_diameter[var.tool]} D2 W0
var fkey = global.result
M98 P"0:/sys/meltingplot/sformat.g" F{global.nozzle_diameter[var.tool]} D2 W0
set global.result = var.fkey ^ "-" ^ global.result
