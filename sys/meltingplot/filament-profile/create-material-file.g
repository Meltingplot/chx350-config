; filament-profile/create-material-file.g
; Offers to create the missing material data file of one filament profile -
; filaments/<S>/material.g - and prompts for its values: density (g/cm3) and the net
; filament weights of the spools the material comes on. The density turns extruded
; millimetres into grams (spool/track.g), the sizes are what the spool prompt at
; filament load offers. The weight of the empty spool is not asked here: it belongs to
; the spool body, not to the material, and comes from the machine's spool catalog
; (global.spool_catalog, see globals).
;   M98 P"0:/sys/meltingplot/filament-profile/create-material-file.g" S"<filament name>"
; Returns immediately when the file already exists: those values are edited in DWC,
; never overwritten from here. The file is only written, never executed - the caller
; runs it when it needs the values (spool/confirm.g does).
; BLOCKING - this prompts the operator. Only call it where blocking is allowed and an
; operator is present: never from daemon.g, from a trigger macro, or from the generated
; filaments/<name>/config.g. Callers: spool/confirm.g (at the filament-load
; prompt), macros create-filament-profile and repair-filament-profile.
; Cancelling any prompt leaves the file unwritten (J2 - a cancelled question must never
; abort the filament load this runs inside; J1 would kill the whole file stack).
; The outcome is handed back in global.result (RRF macros cannot return a value):
; 0 = the file was written by this call, 1 = nothing was written (it already exists,
; the operator declined, or the write failed). Read it on the next line.
; The size list is written as {a,b,} - trailing comma so a single size is still an
; array (RRF 3.5/3.6 array syntax; [] needs 3.7).

if global.debug
  echo "filament-profile/create-material-file.g"

if !exists(param.S)
  M118 P0 S"Error: filament-profile/create-material-file.g: missing S (filament profile name) parameter"
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

; spool sizes: at least one, up to five; the list is built as the literal text of the
; array expression written below
var sizes = ""
var count = 0
var lastSize = 1000
while var.count < 5
  M291 R{"Material: " ^ param.S} P{"Spool size " ^ (var.count + 1) ^ ": net filament weight in grams (1 kg = 1000):"} S5 L1 H50000 F{var.lastSize} J2
  if result != 0
    set global.result = 1
    M99
  set var.lastSize = input
  set var.sizes = var.sizes ^ var.lastSize ^ ","
  set var.count = var.count + 1
  if var.count < 5
    M291 R{"Material: " ^ param.S} P{"Spool sizes so far: " ^ var.count ^ ". Add another spool size?"} S4 K{"Done","Add another"} F0 J2
    if result != 0 || input == 0
      break

; the file explains itself: an operator opens it in DWC, not this macro
echo >{var.file} "; " ^ param.S ^ " - material data. User-editable in DWC, never overwritten by a config update."
echo >>{var.file} "; Read by the spool prompt at every filament load and by macro set-spool-size."
echo >>{var.file} ";"
echo >>{var.file} "; material_density - g/cm3. Turns the extruded millimetres into grams for the spool"
echo >>{var.file} ";   consumption tracker. 0 = consumption is not tracked."
echo >>{var.file} ";   PLA 1.24, PETG 1.27, ABS 1.04, PA 1.14, TPU 1.21 (see the datasheet)"
echo >>{var.file} "set global.material_density = " ^ var.density
echo >>{var.file} ";"
echo >>{var.file} "; material_spool_weights - net filament weight in grams of every spool size this material"
echo >>{var.file} ";   is sold on, offered as the list in the spool prompt (shown in kg: 2300 = 2.3 kg)."
echo >>{var.file} ";   The first entry is preselected for a new spool. Any size not listed can still be"
echo >>{var.file} ";   entered with Other... Keep the comma after the last value: {1000,} is a list,"
echo >>{var.file} ";   {1000} would be a single number."
echo >>{var.file} "set global.material_spool_weights = {" ^ var.sizes ^ "}"
echo >>{var.file} ";"
echo >>{var.file} "; The weight of the empty spool is not set here: it belongs to the spool type, not to"
echo >>{var.file} "; the material - see macro edit-spool-catalog."

; a profile directory that does not exist lets the write fail without an error
if !fileexists(var.file)
  M118 P0 S{"Error: could not write filaments/" ^ param.S ^ "/material.g"}
  set global.result = 1
  M99

M118 P0 S{"filaments/" ^ param.S ^ "/material.g written (" ^ var.count ^ " spool size(s))"}
set global.result = 0
