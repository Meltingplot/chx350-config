; create_material_config.g
; Offers to create the missing material data file of one filament profile -
; filaments/<S>/material.g - and prompts for its values: density (g/cm3) and the spool
; variants the material comes on, each as net filament weight plus the weight of the
; empty spool. The density turns extruded millimetres into grams (spool_track.g), the
; spool variants are what the spool prompt at filament load offers, the empty weight
; lets the operator weigh a spool and enter what is left (weighed - tare).
;   M98 P"0:/sys/meltingplot/create_material_config.g" S"<filament name>"
; Returns immediately when the file already exists: those values are edited in DWC,
; never overwritten from here. The file is only written, never executed - the caller
; runs it when it needs the values (confirm_spool_size.g does).
; BLOCKING - this prompts the operator. Only call it where blocking is allowed and an
; operator is present: never from daemon.g, from a trigger macro, or from the generated
; filaments/<name>/config.g. Callers: confirm_spool_size.g (at the filament-load
; prompt), macros create-filament-profile and repair-filament-profile.
; Cancelling any prompt leaves the file unwritten (J2 - a cancelled question must never
; abort the filament load this runs inside; J1 would kill the whole file stack).
; The outcome is handed back in global.result (RRF macros cannot return a value):
; 0 = the file was written by this call, 1 = nothing was written (it already exists,
; the operator declined, or the write failed). Read it on the next line.
; The spool arrays are written as {a,b,} - parallel, same length, trailing comma so a
; single variant is still an array (RRF 3.5/3.6 array syntax; [] needs 3.7).

if global.debug
  echo "create_material_config.g"

if !exists(param.S)
  M118 P0 S"Error: create_material_config.g: missing S (filament profile name) parameter"
  set global.result = 1
  M99
if param.S == ""
  set global.result = 1
  M99

var file = "0:/filaments/" ^ param.S ^ "/material.g"

; nothing to do - the profile already has its material data
if fileexists(var.file)
  set global.result = 1
  M99

M291 R"Material data" P{"'" ^ param.S ^ "' has no material data (density, spools). Add it now?"} S4 K{"Enter values","Not now"} F0 J2
if result != 0             ; J2 leaves input undefined - result must be tested right here
  set global.result = 1
  M99
if input != 0
  M118 P0 S{"'" ^ param.S ^ "' without material data - filament consumption is not tracked, macro repair-filament-profile adds it later"}
  set global.result = 1
  M99

M291 R{"Material: " ^ param.S} P"Density in g/cm3 (PLA 1.24, PETG 1.27, ABS 1.04, PA 1.14, TPU 1.21):" S6 L0.5 H3 F1.24 J2
if result != 0
  set global.result = 1
  M99
var density = input

; spool variants: at least one, up to five; the lists are built as the literal text of
; the two array expressions written below
var sizes = ""
var weights = ""
var count = 0
var lastSize = 1000
var lastWeight = 0
while var.count < 5
  M291 R{"Material: " ^ param.S} P{"Spool variant " ^ (var.count + 1) ^ ": net filament weight in grams (1 kg = 1000):"} S5 L1 H50000 F{var.lastSize} J2
  if result != 0
    set global.result = 1
    M99
  set var.lastSize = input
  M291 R{"Material: " ^ param.S} P{"Spool variant " ^ (var.count + 1) ^ ": weight of the empty spool in grams (tare, 0 = unknown):"} S5 L0 H5000 F{var.lastWeight} J2
  if result != 0
    set global.result = 1
    M99
  set var.lastWeight = input
  set var.sizes = var.sizes ^ var.lastSize ^ ","
  set var.weights = var.weights ^ var.lastWeight ^ ","
  set var.count = var.count + 1
  if var.count < 5
    M291 R{"Material: " ^ param.S} P{"Spool variants so far: " ^ var.count ^ ". Add another spool size?"} S4 K{"Done","Add another"} F0 J2
    if result != 0 || input == 0
      break

echo >{var.file} "; " ^ param.S ^ " - material data (user-editable): density, spool variants (parallel lists: net filament g, empty spool g)"
echo >>{var.file} "set global.filament_density = " ^ var.density ^ "          ; g/cm3"
echo >>{var.file} "set global.filament_spool_size = {" ^ var.sizes ^ "}       ; g net filament per spool variant"
echo >>{var.file} "set global.filament_spool_weight = {" ^ var.weights ^ "}     ; g empty spool (tare) per variant, 0 = unknown"

; a profile directory that does not exist lets the write fail without an error
if !fileexists(var.file)
  M118 P0 S{"Error: could not write filaments/" ^ param.S ^ "/material.g"}
  set global.result = 1
  M99

M118 P0 S{"filaments/" ^ param.S ^ "/material.g written (" ^ var.count ^ " spool variant(s))"}
set global.result = 0
