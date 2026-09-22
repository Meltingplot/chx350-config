; confirm_spool_size.g
; Records the spool mounted on a tool: nominal net weight as a dropdown ("Other..."
; takes a free value in grams), then what is left on it in grams (a full spool by
; default). Persists size, remaining, the spool's tare and the filament's density in
; global.spool_*[T] and sys/generated/spool<T>.g via store_spool.g - the spool stays
; on the machine across a power cycle; the file is machine-local state, see globals.
;   M98 P"0:/sys/meltingplot/confirm_spool_size.g" T0 A1
; T<tool> is optional and defaults to the current tool. A1 marks a NEW spool (the
; filament-load path): the profile's first spool variant is preselected and "remaining"
; defaults to full. Without A1 (macro set-spool-size, correcting an entry) the tool's
; current size and remaining are preselected.
; The dropdown lists the spool variants of the profile's material.g (parallel arrays
; global.filament_spool_size / _weight) when the filament on the tool has one, else a
; generic size list without tares. material.g is run here after resetting the material
; globals, so a profile without the file never inherits another material's values; a
; missing material.g is offered (create_material_config.g) because the operator is at
; the machine anyway. No density means the spool is not tracked (spool_track.g skips
; density 0).
; M291 K takes the list from a variable: RRF reads K as an expression and accepts any
; string array (GCodes7.cpp, mode 4), so the labels are built at run time. The command
; shape - S4 K{...} F{...} J2 - is the one confirm_nozzle_diameter.g runs on this
; machine; only the K operand is a variable here instead of the literal list, and both
; evaluate to the same string array.
; Cancelling the first prompt keeps everything - J2 (result = -1, execution continues),
; never J1: load_filament_sensorless runs this at the feed prompt and a confirmation
; must never abort a load. Cancelling the "remaining" prompt records a full spool.
; Grams as an int: 1 kg is stored as 1000. 0 = unknown.

if global.debug
  echo "confirm_spool_size.g"

var tool = exists(param.T) ? ((param.T == 1) ? 1 : 0) : min(max(state.currentTool, 0), 1)
var newSpool = exists(param.A) && param.A == 1

; material data of the filament on this tool: density for the tracker, spool variants
; for the dropdown. Reset first - a profile without material.g must read as unknown.
set global.filament_density = 0.0
set global.filament_spool_size = vector(0, 0)
set global.filament_spool_weight = vector(0, 0)
var filament = ""
if tools[var.tool] != null
  set var.filament = move.extruders[tools[var.tool].extruders[0]].filament
if var.filament != null && var.filament != ""
  if !fileexists("0:/filaments/" ^ var.filament ^ "/material.g")
    M98 P"0:/sys/meltingplot/create_material_config.g" S{var.filament}
  if fileexists("0:/filaments/" ^ var.filament ^ "/material.g")
    M98 P{"0:/filaments/" ^ var.filament ^ "/material.g"}

; the choice lists: the profile's variants, else the generic sizes. tares run parallel
; to sizes; labels get one extra entry, "Other...", at index #sizes
var sizes = {250, 500, 750, 1000, 2000, 2500, 3000, 5000, 8000}
var tares = vector(9, 0)
var labels = {"250 g", "500 g", "750 g", "1 kg", "2 kg", "2.5 kg", "3 kg", "5 kg", "8 kg", "Other..."}
if #global.filament_spool_size > 0 && #global.filament_spool_size == #global.filament_spool_weight
  set var.sizes = global.filament_spool_size
  set var.tares = global.filament_spool_weight
  set var.labels = vector(#var.sizes + 1, "Other...")
  while iterations < #var.sizes
    set var.labels[iterations] = var.sizes[iterations] ^ " g" ^ (var.tares[iterations] > 0 ? " (spool " ^ var.tares[iterations] ^ " g)" : "")
elif #global.filament_spool_size > 0
  M118 P0 S{"Warning: filaments/" ^ var.filament ^ "/material.g: spool size and weight lists differ in length - using the generic sizes"}

; preselect: a new spool takes the profile's first variant, else the tool's current
; size; nothing known preselects 1 kg (generic) or the first variant, an off-list value
; "Other..."
var preset = global.spool_size[var.tool]
if var.newSpool && #global.filament_spool_size > 0
  set var.preset = global.filament_spool_size[0]
var choice = (#global.filament_spool_size > 0) ? 0 : 3
if var.preset > 0
  set var.choice = #var.sizes
  while iterations < #var.sizes
    if var.sizes[iterations] == var.preset
      set var.choice = iterations
      break

M291 R"Spool size" P{"Net filament weight of the spool on tool " ^ var.tool ^ "?"} S4 K{var.labels} F{var.choice} J2
if result != 0             ; J2 leaves input undefined - result must be tested right here
  M99
set var.choice = input

var grams = 0
var tare = 0
if var.choice < #var.sizes
  set var.grams = var.sizes[var.choice]
  set var.tare = var.tares[var.choice]
else
  M291 R"Spool size" P{"Net filament weight of the spool on tool " ^ var.tool ^ " in grams:"} S5 L1 H50000 F{max(var.preset, 1)} J2
  if result != 0
    M99
  set var.grams = input
  M291 R"Spool size" P{"Weight of that spool when empty in grams (tare, 0 = unknown):"} S5 L0 H5000 F{global.spool_tare[var.tool]} J2
  if result == 0
    set var.tare = input

; what is left: a new spool or a changed size defaults to full, a correction to the
; tracked value. Cancelling here records a full spool rather than dropping the entry.
var remaining = var.grams
if !var.newSpool && var.grams == global.spool_size[var.tool]
  set var.remaining = min(var.grams, floor(global.spool_remaining[var.tool]))
M291 R"Spool size" P{"Filament left on the spool of tool " ^ var.tool ^ " in grams (full = " ^ var.grams ^ "; weighed spool minus " ^ var.tare ^ " g tare):"} S5 L0 H{var.grams} F{var.remaining} J2
if result == 0
  set var.remaining = input

set global.spool_size[var.tool] = var.grams
set global.spool_remaining[var.tool] = var.remaining
set global.spool_tare[var.tool] = var.tare
set global.spool_density[var.tool] = global.filament_density
; the tracker books from here on: a spool entered mid-print (paused filament change)
; must not be charged with what the print extruded before it went on
if tools[var.tool] != null
  set global.spool_track_raw[var.tool] = move.extruders[tools[var.tool].extruders[0]].rawPosition

M98 P"0:/sys/meltingplot/store_spool.g" T{var.tool}

if global.filament_density > 0
  M118 P0 S{"Tool " ^ var.tool ^ ": " ^ var.remaining ^ " g of " ^ var.grams ^ " g spool, " ^ global.filament_density ^ " g/cm3"}
else
  M118 P0 S{"Tool " ^ var.tool ^ ": " ^ var.remaining ^ " g of " ^ var.grams ^ " g spool - no density known, consumption is not tracked"}
