; load_nozzle_config.g
; Runs filaments/<S>/nozzle-<key>.g of the nozzle installed on the current tool, if it
; exists. A missing file is not an error - the material-wide values of config-override.g
; then stand, which keeps profiles predating the per-nozzle split working.
; Called from the machine-generated filaments/<S>/config.g, right after config-override.g:
;   M98 P"0:/sys/meltingplot/load_nozzle_config.g" S"<filament name>"
; This logic deliberately lives here and not in the generated config.g: emitting it with
; echo would require quotes inside quotes, and a single mis-escaped one produces an
; unterminated string that breaks every filament profile at once.

if global.debug
  echo "load_nozzle_config.g"

if !exists(param.S)
  M99
if param.S == ""
  M99

; M703 can run without a tool selected - fall back to tool 0 rather than indexing with -1
var t = max(state.currentTool, 0)
; sformat.g returns the key in global.result - read it straight away
M98 P"0:/sys/meltingplot/sformat.g" F{global.nozzle_diameter[var.t]} D2 W0
var nozzle = "0:/filaments/" ^ param.S ^ "/nozzle-" ^ global.result ^ ".g"

if fileexists(var.nozzle)
  M98 P{var.nozzle}
