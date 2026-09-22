; create_nozzle_config.g
; Offers to create the missing parameter file of the installed filament diameter and
; nozzle for one filament profile - filaments/<S>/nozzle-<key>.g, <key> = "2.85-0.40"
; from calibration_key.g - and prompts for its values (max volumetric flow rate,
; pressure advance, firmware retraction, heater feedforward).
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

; nothing to do when the profile already describes this filament/nozzle pair - through
; the same fallback chain load_nozzle_config.g uses, so a nozzle-only file from before
; the filament suffix does not trigger a duplicate offer on a 2.85 mm tool.
; find_calibration_file.g returns the resolved path in global.result - read it straight away
M98 P"0:/sys/meltingplot/find_calibration_file.g" S{param.S} F"nozzle" T{var.tool}
if global.result != ""
  set global.result = 1
  M99

; the key is "<filament>-<nozzle>" (calibration_key.g, returns in global.result - read it
; straight away); the raw floats must never build a file name, see globals
M98 P"0:/sys/meltingplot/calibration_key.g" T{var.tool}
var key = global.result
var file = "0:/filaments/" ^ param.S ^ "/nozzle-" ^ var.key ^ ".g"

; defaults, overwritten below when the operator enters the values
var flow = 20
var pa = 0.05
var retract = 0.8
var retractF = 1250
var retractT = 840
var retractZ = 0.25
var ffPwm = 0.0
var ffTemp = 0.0

M291 R{"Filament/nozzle " ^ var.key} P{"'" ^ param.S ^ "' has no parameters for filament/nozzle " ^ var.key ^ " mm. Add them now?"} S4 K{"Enter values","Use defaults","Not now"} F0 J2
if result != 0             ; J2 leaves input undefined - result must be tested right here
  set global.result = 1
  M99
if input == 2
  M118 P0 S{"'" ^ param.S ^ "' keeps running on its material values - macro create-filament-profile adds the " ^ var.key ^ " values later"}
  set global.result = 1
  M99

if input == 0
  M291 R{"Filament/nozzle " ^ var.key} P"Maximum volumetric flow rate in mm3/s (used by the NLE calibration):" S5 L1 H100 F{var.flow} J2
  if result != 0
    set global.result = 1
    M99
  set var.flow = input
  M291 R{"Filament/nozzle " ^ var.key} P"Pressure advance (M572 S) in seconds:" S6 L0 H2 F{var.pa} J2
  if result != 0
    set global.result = 1
    M99
  set var.pa = input
  M291 R{"Filament/nozzle " ^ var.key} P"Firmware retraction length (M207 S) in mm:" S6 L0 H10 F{var.retract} J2
  if result != 0
    set global.result = 1
    M99
  set var.retract = input
  M291 R{"Filament/nozzle " ^ var.key} P"Retraction speed (M207 F) in mm/min:" S5 L60 H6000 F{var.retractF} J2
  if result != 0
    set global.result = 1
    M99
  set var.retractF = input
  M291 R{"Filament/nozzle " ^ var.key} P"Un-retraction speed (M207 T) in mm/min:" S5 L60 H6000 F{var.retractT} J2
  if result != 0
    set global.result = 1
    M99
  set var.retractT = input
  M291 R{"Filament/nozzle " ^ var.key} P"Z hop on retraction (M207 Z) in mm:" S6 L0 H2 F{var.retractZ} J2
  if result != 0
    set global.result = 1
    M99
  set var.retractZ = input
  M291 R{"Filament/nozzle " ^ var.key} P"Heater feedforward extrusion rate -> heater PWM (M309 S). 0 = off:" S6 L0 H1 F{var.ffPwm} J2
  if result != 0
    set global.result = 1
    M99
  set var.ffPwm = input
  M291 R{"Filament/nozzle " ^ var.key} P"Heater feedforward extrusion rate -> temperature (M309 T). 0 = off:" S6 L0 H50 F{var.ffTemp} J2
  if result != 0
    set global.result = 1
    M99
  set var.ffTemp = input

; all four are written unconditionally, not only where they differ from the default,
; because they are global machine state: whatever the previously loaded filament set
; stays active until this profile overwrites it
echo >{var.file} "; " ^ param.S ^ " - parameters for filament/nozzle " ^ var.key ^ " mm, selected by config.g"
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
