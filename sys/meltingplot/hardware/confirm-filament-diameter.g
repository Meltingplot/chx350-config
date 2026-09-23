; hardware/confirm-filament-diameter.g
; Asks which filament diameter a tool is set up for, as a dropdown with the configured
; value preselected ("Other..." takes a free value), persists a change in
; global.filament_diameter[T] and sys/generated/filament-diameter<T>.g (machine-local
; state, see globals) and applies it at once with M200 - the value config.g uses at boot.
;   M98 P"0:/sys/meltingplot/hardware/confirm-filament-diameter.g" T0
; T<tool> is optional and defaults to the current tool. Cancelling keeps the configured
; value - J2 (result = -1, execution continues), never J1. Called by macro
; set-filament-diameter. M200 waits for standstill, so this must never run from daemon.g.

if global.debug
  echo "hardware/confirm-filament-diameter.g"

var tool = exists(param.T) ? ((param.T == 1) ? 1 : 0) : min(max(state.currentTool, 0), 1)

; preselect the configured diameter; an off-list value preselects "Other..."
var choice = 2
if global.filament_diameter[var.tool] == 1.75
  set var.choice = 0
elif global.filament_diameter[var.tool] == 2.85
  set var.choice = 1

M291 R"Filament diameter" P{"Filament diameter of tool " ^ var.tool ^ "?"} S4 K{"1.75 mm","2.85 mm","Other..."} F{var.choice} J2
if result != 0             ; J2 leaves input undefined - result must be tested right here
  M99
set var.choice = input

var diameter = global.filament_diameter[var.tool]
if var.choice == 0
  set var.diameter = 1.75
elif var.choice == 1
  set var.diameter = 2.85
else
  M291 R"Filament diameter" P{"Filament diameter of tool " ^ var.tool ^ " in mm:"} S6 L1 H4 F{global.filament_diameter[var.tool]} J2
  if result != 0
    M99
  set var.diameter = input

if var.diameter == global.filament_diameter[var.tool]
  M99                      ; confirmed unchanged - nothing to persist

set global.filament_diameter[var.tool] = var.diameter

; the tool index is built as a string explicitly so that no float formatting can leak into
; the file name or into the array index of the generated assignment
var idx = var.tool == 1 ? "1" : "0"
var file = "0:/sys/generated/filament-diameter" ^ var.idx ^ ".g"
echo >{var.file} "; filament diameter of tool " ^ var.idx ^ " - written by hardware/confirm-filament-diameter.g, do not edit"
echo >>{var.file} "set global.filament_diameter[" ^ var.idx ^ "] = " ^ var.diameter

; apply for this session the way config.g does at boot (one extruder per tool, D0 on tool 0)
M200 D{global.filament_diameter[0]} S0

M118 P0 S{"Tool " ^ var.tool ^ " filament diameter set to " ^ var.diameter ^ " mm - check the e-steps and the MFM calibration"}
