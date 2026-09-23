; spool/confirm.g
; Records the spool mounted on a tool in three questions: the nominal net filament
; weight as a dropdown ("Other..." takes a free value in grams), the spool body as a
; dropdown of the machine's spool catalog, which gives the weight of the empty spool
; (tare), and the spool's weight on a scale - what is left is scale minus tare, a full
; spool by default. Persists size, remaining, the tare and the filament's density in
; global.spool_*[T] and sys/generated/spool<T>.g via spool/store.g - the spool stays on
; the machine across a power cycle; the file is machine-local state, see globals.
;   M98 P"0:/sys/meltingplot/spool/confirm.g" T0 A1
; T<tool> is optional and defaults to the current tool of the calling channel's motion
; system (state.currentTool is per motion system) - callers that know their tool pass
; it. A1 marks a NEW spool (the
; filament-load path): the profile's first spool size is preselected and the scale
; weight defaults to a full spool. Without A1 (macro set-spool-size, correcting an
; entry) the tool's current size and remaining are preselected. The spool body is
; preselected by the tool's current tare either way: the next spool mostly comes from
; the same supplier.
; Sizes: the net weights listed in the profile's material.g (global.material_spool_weights)
; when the filament on the tool has one, else a generic list. material.g is run here
; after resetting the material globals, so a profile without the file never inherits
; another material's values; a missing material.g is offered (filament-profile/create-material-file.g)
; because the operator is at the machine anyway. No density means the spool is not
; tracked (spool/track.g skips density 0).
; Spool bodies: global.spool_catalog, flat pairs {"<name>",<tare g>,...} - declared with
; the default list in globals, replaced by the machine's own list from
; sys/overrides/spool-catalog.csv (macro edit-spool-catalog, or edited in DWC), which
; spool/read-catalog.g reads here rather than at boot, so an edit applies at once and a
; broken file can only affect this prompt. The tare belongs to the spool body, not to the material or the size: two 2.3 kg spools of
; different make weigh differently when empty. An empty catalog, or "Other...", asks
; the tare as a number.
; M291 K takes the list from a variable: RRF reads K as an expression and accepts any
; string array (GCodes7.cpp, mode 4), so the labels are built at run time. The command
; shape - S4 K{...} F{...} J2 - is the one hardware/confirm-nozzle-diameter.g runs on this
; machine; only the K operand is a variable here instead of the literal list, and both
; evaluate to the same string array.
; Cancelling the first prompt keeps everything - J2 (result = -1, execution continues),
; never J1: filament/load-procedure.g runs this at the feed prompt and a confirmation
; must never abort a load. Cancelling the spool-body prompt keeps the tool's tare,
; cancelling the scale prompt records a full spool.
; Grams as an int: 1 kg is stored as 1000. 0 = unknown.

if global.debug
  echo "spool/confirm.g"

var tool = exists(param.T) ? ((param.T == 1) ? 1 : 0) : min(max(state.currentTool, 0), 1)
var newSpool = exists(param.A) && param.A == 1

; material data of the filament on this tool: density for the tracker, spool sizes for
; the dropdown. A missing material.g is offered first (blocking prompts).
var filament = ""
if tools[var.tool] != null
  set var.filament = move.extruders[tools[var.tool].extruders[0]].filament
var known = var.filament != null && var.filament != ""
if var.known && !fileexists("0:/filaments/" ^ var.filament ^ "/material.g")
  M98 P"0:/sys/meltingplot/filament-profile/create-material-file.g" S{var.filament}

; material.g hands its values over in global.material_density / material_spool_weights,
; which both tools share - with T0 and T1 loading in different motion systems another
; run may write them at any time. So: reset, run and take them into locals as three
; consecutive steps with no prompt in between, and read only the locals afterwards. The
; reset makes a profile without material.g read as unknown instead of inheriting what
; the other tool's run left behind.
var sizes = {250, 500, 750, 1000, 2000, 2500, 3000, 5000, 8000}   ; generic list, g
set global.material_density = 0.0
set global.material_spool_weights = vector(0, 0)
if var.known && fileexists("0:/filaments/" ^ var.filament ^ "/material.g")
  M98 P{"0:/filaments/" ^ var.filament ^ "/material.g"}
var density = global.material_density
var profileSizes = #global.material_spool_weights > 0
if var.profileSizes
  set var.sizes = global.material_spool_weights

; --- 1: net filament weight - the profile's sizes (above), else the generic list

; the labels are built from the weights (grams), so there is only one list to maintain:
; always in kg with as many decimals as needed - 1000 "1 kg", 2300 "2.3 kg", 750
; "0.75 kg", 2250 "2.25 kg", 5 "0.005 kg" - plus "Other..." at index #sizes. Integer
; arithmetic only: a computed float would render with all its decimal places (see
; lib/format-number.g), so the fraction is built from the gram remainder, zero-padded, trailing
; zeros dropped
var labels = vector(#var.sizes + 1, "Other...")
var g = 0
var frac = ""
while iterations < #var.sizes
  set var.g = mod(var.sizes[iterations], 1000)
  if var.g == 0
    set var.frac = ""
  elif mod(var.g, 100) == 0
    set var.frac = "." ^ floor(var.g / 100)
  elif mod(var.g, 10) == 0
    set var.frac = ((var.g < 100) ? ".0" : ".") ^ floor(var.g / 10)
  else
    set var.frac = ((var.g < 10) ? ".00" : ((var.g < 100) ? ".0" : ".")) ^ var.g
  set var.labels[iterations] = floor(var.sizes[iterations] / 1000) ^ var.frac ^ " kg"

; preselect: a new spool takes the profile's first size, else the tool's current size;
; nothing known preselects 1 kg (generic) or the first size, an off-list value "Other..."
var preset = global.spool_net_weight[var.tool]
if var.newSpool && var.profileSizes
  set var.preset = var.sizes[0]
var choice = var.profileSizes ? 0 : 3
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
if var.choice < #var.sizes
  set var.grams = var.sizes[var.choice]
else
  M291 R"Spool size" P{"Net filament weight of the spool on tool " ^ var.tool ^ " in grams:"} S5 L1 H50000 F{max(var.preset, 1)} J2
  if result != 0
    M99
  set var.grams = input

; --- 2: spool body -> tare. The machine's own catalog replaces the default list; spool
; type i is the pair [i + i] name, [i + i + 1] tare. Preselected is the first entry
; with the tool's current tare, else the first entry; a known tare that is in no entry
; preselects "Other...". Cancelling keeps the tool's tare.
M98 P"0:/sys/meltingplot/spool/read-catalog.g"
var tare = global.spool_tare[var.tool]
var other = true
var types = floor(#global.spool_catalog / 2)
if var.types > 0
  set var.labels = vector(var.types + 1, "Other...")
  set var.choice = (global.spool_tare[var.tool] > 0) ? var.types : 0
  while iterations < var.types
    set var.labels[iterations] = global.spool_catalog[iterations + iterations] ^ " (" ^ global.spool_catalog[iterations + iterations + 1] ^ " g)"
    if var.choice == var.types && global.spool_catalog[iterations + iterations + 1] == global.spool_tare[var.tool]
      set var.choice = iterations
  M291 R"Spool size" P{"Which spool is on tool " ^ var.tool ^ "? (weight when empty)"} S4 K{var.labels} F{var.choice} J2
  if result != 0          ; J2 leaves input undefined - result must be tested right here
    set var.other = false
  elif input < var.types
    set var.tare = global.spool_catalog[input + input + 1]
    set var.other = false
if var.other
  M291 R"Spool size" P"Weight of the empty spool in grams (tare, 0 = unknown):" S5 L0 H5000 F{floor(global.spool_tare[var.tool])} J2
  if result == 0
    set var.tare = input

; --- 3: what is left. A new spool or a changed size defaults to full, a correction to
; the tracked value. With a known tare the operator enters what the scale shows and the
; tare is subtracted here; without one the prompt asks for the filament weight itself.
; Cancelling records the default rather than dropping the entry.
var remaining = var.grams
if !var.newSpool && var.grams == global.spool_net_weight[var.tool]
  set var.remaining = min(var.grams, floor(global.spool_remaining[var.tool]))
var ask = "Filament left on the spool of tool " ^ var.tool ^ " in grams (full = " ^ var.grams ^ "):"
if var.tare > 0
  set var.ask = "Spool of tool " ^ var.tool ^ " on a scale, in grams (full = " ^ (var.grams + var.tare) ^ ", empty spool = " ^ var.tare ^ "):"
M291 R"Spool size" P{var.ask} S5 L0 H50000 F{floor(var.remaining + var.tare)} J2
if result == 0
  set var.remaining = min(var.grams, max(0, input - var.tare))

set global.spool_net_weight[var.tool] = var.grams
set global.spool_remaining[var.tool] = var.remaining
set global.spool_tare[var.tool] = var.tare
set global.spool_density[var.tool] = var.density
; the tracker books from here on: the entered weight already reflects everything
; extruded before (a paused filament change, the purge of the load that asked this)
if tools[var.tool] != null
  set global.spool_track_baseline[var.tool] = move.extruders[tools[var.tool].extruders[0]].position

M98 P"0:/sys/meltingplot/spool/store.g" T{var.tool}

if var.density > 0
  M118 P0 S{"Tool " ^ var.tool ^ ": " ^ floor(var.remaining) ^ " g of " ^ var.grams ^ " g spool (empty " ^ var.tare ^ " g), " ^ var.density ^ " g/cm3"}
else
  M118 P0 S{"Tool " ^ var.tool ^ ": " ^ floor(var.remaining) ^ " g of " ^ var.grams ^ " g spool - no density known, consumption is not tracked"}
