; hardware/confirm-nozzle-type.g
; Asks which kind of nozzle is installed on a tool - material and CHT geometry - as a
; dropdown with the configured type preselected, and persists a change in
; global.nozzle_type[T] and sys/generated/nozzle-type<T>.g (a nozzle change must
; survive a power cycle; the file is machine-local state, see globals).
;   M98 P"0:/sys/meltingplot/hardware/confirm-nozzle-type.g" T0
; T<tool> is optional and defaults to the current tool. Cancelling keeps the configured
; value - J2 (result = -1, execution continues), never J1: the caller may be a load path.
; Called by macro set-nozzle-diameter, which asks for diameter and type in one go.
; The key list must stay in step with the K list of the M291 below (same order).

if global.debug
  echo "hardware/confirm-nozzle-type.g"

var tool = exists(param.T) ? ((param.T == 1) ? 1 : 0) : min(max(state.currentTool, 0), 1)
var keys = {"brass", "cht", "hardened", "cht-hardened", "tungsten-carbide", "copper", "other"}

; preselect the configured type; "unknown" or an off-list key preselects the first entry
var choice = 0
while iterations < #var.keys
  if var.keys[iterations] == global.nozzle_type[var.tool]
    set var.choice = iterations
    break

M291 R"Nozzle type" P{"Which nozzle is installed on tool " ^ var.tool ^ "?"} S4 K{"Brass","Brass CHT","Hardened steel","Hardened steel CHT","Tungsten carbide","Plated copper","Other"} F{var.choice} J2
if result != 0             ; J2 leaves input undefined - result must be tested right here
  M99
var key = var.keys[input]

if var.key == global.nozzle_type[var.tool]
  M99                      ; confirmed unchanged - nothing to persist

set global.nozzle_type[var.tool] = var.key

; the tool index is built as a string explicitly so that no float formatting can leak into
; the file name or into the array index of the generated assignment
var idx = var.tool == 1 ? "1" : "0"
var file = "0:/sys/generated/nozzle-type" ^ var.idx ^ ".g"
echo >{var.file} "; nozzle type of tool " ^ var.idx ^ " - written by hardware/confirm-nozzle-type.g, do not edit"
echo >>{var.file} "set global.nozzle_type[" ^ var.idx ^ "] = """ ^ var.key ^ """"

M118 P0 S{"Tool " ^ var.tool ^ " nozzle type set to " ^ var.key}
