; filament-profile/find-calibration-file.g
; Resolves which file of a filament profile describes the installed hardware, with the
; fallback chain for files written before the key carried the filament diameter:
;   1. filaments/<S>/<F>-<filament>-<nozzle>.g   the current key (filament-profile/calibration-key.g)
;   2. filaments/<S>/<F>-<nozzle>.g              nozzle-only key, ONLY while the tool runs
;                                                2.85 mm filament: every file of that era
;                                                was measured with 2.85 mm, so on a 1.75 mm
;                                                tool it would be a silent wrong hit
;   3. filaments/<S>/<F>.g                       unsuffixed, from before the per-nozzle split
;   M98 P"0:/sys/meltingplot/filament-profile/find-calibration-file.g" S"<filament name>" F"config-auto-nle" T0
; F is the base name (config-auto-esteps, config-auto-nle, config-auto-pa, nozzle),
; T<tool> is optional and defaults to the current tool. The full path of the first file
; that exists is handed back in global.result, "" when none does - read it on the next
; line (RRF macros cannot return a value; global.result is only valid right after the
; call). Readers: tpost0.g (loads the three calibration results), filament-profile/apply-nozzle-file.g,
; filament/load-procedure.g (is an NLE calibration present?), filament-profile/create-nozzle-file.g and
; macro create-filament-profile (does the profile already describe this hardware?).
; The key format lives in filament-profile/calibration-key.g; it is repeated here because the fallback
; needs the nozzle half on its own and RRF has no substring operator.

if global.debug
  echo "filament-profile/find-calibration-file.g"

if !exists(param.S) || !exists(param.F) || param.S == "" || param.F == ""
  M118 P0 S"Error: filament-profile/find-calibration-file.g: missing S (filament) or F (base name) parameter"
  set global.result = ""
  M99

var tool = exists(param.T) ? ((param.T == 1) ? 1 : 0) : min(max(state.currentTool, 0), 1)
var base = "0:/filaments/" ^ param.S ^ "/" ^ param.F

; lib/format-number.g returns in global.result - read it straight away, each time
M98 P"0:/sys/meltingplot/lib/format-number.g" F{global.nozzle_diameter[var.tool]} D2 W0
var nkey = global.result
M98 P"0:/sys/meltingplot/lib/format-number.g" F{global.filament_diameter[var.tool]} D2 W0
var fkey = global.result

set global.result = ""
if fileexists(var.base ^ "-" ^ var.fkey ^ "-" ^ var.nkey ^ ".g")
  set global.result = var.base ^ "-" ^ var.fkey ^ "-" ^ var.nkey ^ ".g"
elif var.fkey == "2.85" && fileexists(var.base ^ "-" ^ var.nkey ^ ".g")
  set global.result = var.base ^ "-" ^ var.nkey ^ ".g"
elif fileexists(var.base ^ ".g")
  set global.result = var.base ^ ".g"
