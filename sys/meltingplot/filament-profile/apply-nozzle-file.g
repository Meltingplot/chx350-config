; filament-profile/apply-nozzle-file.g
; Runs filaments/<S>/nozzle-<key>.g of the filament diameter and nozzle installed on the
; current tool (<key> = "2.85-0.40", filament-profile/calibration-key.g), if it exists - resolved through
; filament-profile/find-calibration-file.g, so a nozzle-only file from before the filament suffix is still
; used on a 2.85 mm tool. A missing file is not an error - the material-wide values of
; config-override.g then stand, which keeps profiles predating the per-nozzle split working.
; Called from the machine-generated filaments/<S>/config.g, right after config-override.g:
;   M98 P"0:/sys/meltingplot/filament-profile/apply-nozzle-file.g" S"<filament name>"
; This logic deliberately lives here and not in the generated config.g: emitting it with
; echo would require quotes inside quotes, and a single mis-escaped one produces an
; unterminated string that breaks every filament profile at once.

if global.debug
  echo "filament-profile/apply-nozzle-file.g"

if !exists(param.S)
  M99
if param.S == ""
  M99

; M703 can run without a tool selected - fall back to tool 0 rather than indexing with -1
; filament-profile/find-calibration-file.g returns the resolved path in global.result - read it straight away
M98 P"0:/sys/meltingplot/filament-profile/find-calibration-file.g" S{param.S} F"nozzle" T{max(state.currentTool, 0)}
var nozzle = global.result

if var.nozzle != ""
  M98 P{var.nozzle}
