; create_nozzle_config.g
; Offers to create the missing parameter file of the installed nozzle for one filament
; profile - filaments/<S>/nozzle-<key>.g - and prompts for its values (max volumetric
; flow rate, pressure advance, firmware retraction, heater feedforward).
;   M98 P"0:/sys/meltingplot/create_nozzle_config.g" S"<filament name>" T0
; T<tool> is optional and defaults to the current tool.
; A profile describes a MATERIAL, not a material/nozzle combination, so one profile
; collects one nozzle-<key>.g per nozzle it has been used with. Returns immediately when
; the file already exists: those values are edited in DWC, never overwritten from here.
; The file is only written, never executed - applying it is the caller's job, because the
; callers differ: confirm_nozzle_diameter.g and macro set-nozzle-diameter run
; load_nozzle_config.g afterwards, while macro create-filament-profile writes for a
; profile that is not loaded at all.
; BLOCKING - this prompts the operator. Only call it where blocking is allowed and an
; operator is present: never from daemon.g, from a trigger macro, or from the generated
; filaments/<name>/config.g, which also runs from print_start, pause.g and resume.g,
; where a prompt would stall the print. That is why the offer sits in the interactive
; callers and not in load_nozzle_config.g, which they all pass through.
; Cancelling any prompt leaves the file unwritten (J2 - a cancelled question must never
; abort the filament load this runs inside; J1 would kill the whole file stack).
; The outcome is handed back in global.result (RRF macros cannot return a value):
; 0 = the file was written by this call and the caller should apply it, 1 = nothing was
; written (it already exists, the operator declined, or the write failed). Read it on the
; next line, see the global.result rule in globals.

if global.debug
  echo "create_nozzle_config.g"

if !exists(param.S)
  M118 P0 S"Error: create_nozzle_config.g: missing S (filament profile name) parameter"
  set global.result = 1
  M99
if param.S == ""
  set global.result = 1
  M99

var tool = exists(param.T) ? ((param.T == 1) ? 1 : 0) : min(max(state.currentTool, 0), 1)

; two decimals of fixed width - see globals: the raw float must never build a file name.
; sformat.g returns the key in global.result - read it straight away
M98 P"0:/sys/meltingplot/sformat.g" F{global.nozzle_diameter[var.tool]} D2 W0
var key = global.result
var file = "0:/filaments/" ^ param.S ^ "/nozzle-" ^ var.key ^ ".g"

; nothing to do - the profile already describes this nozzle
if fileexists(var.file)
  set global.result = 1
  M99

; defaults, overwritten below when the operator enters the values
var flow = 20
var pa = 0.05
var retract = 0.8
var retractF = 1250
var retractT = 840
var retractZ = 0.25
var ffPwm = 0.0
var ffTemp = 0.0

M291 R{"Nozzle " ^ var.key ^ "mm"} P{"'" ^ param.S ^ "' has no parameters for the " ^ var.key ^ "mm nozzle. Add them now?"} S4 K{"Enter values","Use defaults","Not now"} F0 J2
if result != 0             ; J2 leaves input undefined - result must be tested right here
  set global.result = 1
  M99
if input == 2
  M118 P0 S{"'" ^ param.S ^ "' keeps running on its material values - macro create-filament-profile adds " ^ var.key ^ "mm values later"}
  set global.result = 1
  M99

if input == 0
  M291 R{"Nozzle " ^ var.key ^ "mm"} P"Maximum volumetric flow rate in mm3/s (used by the NLE calibration):" S5 L1 H100 F{var.flow} J2
  if result != 0
    set global.result = 1
    M99
  set var.flow = input
  M291 R{"Nozzle " ^ var.key ^ "mm"} P"Pressure advance (M572 S) in seconds:" S6 L0 H2 F{var.pa} J2
  if result != 0
    set global.result = 1
    M99
  set var.pa = input
  M291 R{"Nozzle " ^ var.key ^ "mm"} P"Firmware retraction length (M207 S) in mm:" S6 L0 H10 F{var.retract} J2
  if result != 0
    set global.result = 1
    M99
  set var.retract = input
  M291 R{"Nozzle " ^ var.key ^ "mm"} P"Retraction speed (M207 F) in mm/min:" S5 L60 H6000 F{var.retractF} J2
  if result != 0
    set global.result = 1
    M99
  set var.retractF = input
  M291 R{"Nozzle " ^ var.key ^ "mm"} P"Un-retraction speed (M207 T) in mm/min:" S5 L60 H6000 F{var.retractT} J2
  if result != 0
    set global.result = 1
    M99
  set var.retractT = input
  M291 R{"Nozzle " ^ var.key ^ "mm"} P"Z hop on retraction (M207 Z) in mm:" S6 L0 H2 F{var.retractZ} J2
  if result != 0
    set global.result = 1
    M99
  set var.retractZ = input
  M291 R{"Nozzle " ^ var.key ^ "mm"} P"Heater feedforward extrusion rate -> heater PWM (M309 S). 0 = off:" S6 L0 H1 F{var.ffPwm} J2
  if result != 0
    set global.result = 1
    M99
  set var.ffPwm = input
  M291 R{"Nozzle " ^ var.key ^ "mm"} P"Heater feedforward extrusion rate -> temperature (M309 T). 0 = off:" S6 L0 H50 F{var.ffTemp} J2
  if result != 0
    set global.result = 1
    M99
  set var.ffTemp = input

; all four are written unconditionally, not only where they differ from the default,
; because they are global machine state: whatever the previously loaded filament set
; stays active until this profile overwrites it
echo >{var.file} "; " ^ param.S ^ " - parameters for the " ^ var.key ^ "mm nozzle, selected by config.g"
echo >>{var.file} "set global.filament_max_flow_rate = " ^ var.flow
echo >>{var.file} "M572 D0 S" ^ var.pa ^ "     ; pressure advance"
echo >>{var.file} "M207 S" ^ var.retract ^ " R0 F" ^ var.retractF ^ " T" ^ var.retractT ^ " Z" ^ var.retractZ ^ "     ; firmware retraction"
echo >>{var.file} "M309 P0 S" ^ var.ffPwm ^ " T" ^ var.ffTemp ^ "     ; heater feedforward"

; a profile directory that does not exist lets the write fail without an error
if !fileexists(var.file)
  M118 P0 S{"Error: could not write filaments/" ^ param.S ^ "/nozzle-" ^ var.key ^ ".g"}
  set global.result = 1
  M99

M118 P0 S{"filaments/" ^ param.S ^ "/nozzle-" ^ var.key ^ ".g written - calibrate PA and NLE for this nozzle"}
set global.result = 0
