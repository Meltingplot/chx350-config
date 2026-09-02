; store_nozzle_diameter.g
; Persists the nozzle diameter of one tool: assigns global.nozzle_diameter[T] and writes
; sys/meltingplot/nozzle<T>.g, which sys/meltingplot/globals runs on every boot - a nozzle
; change must survive a power cycle. Those files are machine-local state: they are written
; on the machine, never shipped with the repo, and a config update must not overwrite them.
;   M98 P"0:/sys/meltingplot/store_nozzle_diameter.g" D0.6 T0
; The two-decimal nozzle key is handed back in global.result (RRF macros cannot return a
; value) - read it on the next line, see the global.result rule in globals.
; This macro only persists. Applying the new values to the loaded filament is the caller's
; job, because the two callers cannot use the same command: macro set-nozzle-diameter runs
; M703, while confirm_nozzle_diameter.g runs inside the filament profile's config.g and
; must use load_nozzle_config.g instead (M703 would re-enter the executing file).

if global.debug
  echo "store_nozzle_diameter.g"

if !exists(param.D)
  M118 P0 S"Error: store_nozzle_diameter.g: missing D (nozzle diameter) parameter"
  set global.result = ""    ; still a string, so the caller cannot read a stale key
  M99

var tool = (exists(param.T) && param.T == 1) ? 1 : 0
set global.nozzle_diameter[var.tool] = param.D

; two decimals of fixed width - see globals: the raw float must never build a file name.
; sformat.g returns the key in global.result - read it straight away
M98 P"0:/sys/meltingplot/sformat.g" F{global.nozzle_diameter[var.tool]} D2 W0
var key = global.result

; the tool index is built as a string explicitly so that no float formatting can leak into
; the file name or into the array index of the generated assignment
var idx = var.tool == 1 ? "1" : "0"
var file = "0:/sys/meltingplot/nozzle" ^ var.idx ^ ".g"
echo >{var.file} "; nozzle diameter of tool " ^ var.idx ^ " - written by store_nozzle_diameter.g, do not edit"
echo >>{var.file} "set global.nozzle_diameter[" ^ var.idx ^ "] = " ^ var.key

set global.result = var.key
