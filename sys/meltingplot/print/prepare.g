M107                                        ; fan off
M144 P0 S1                                  ; activate bed 1 heater
T0                                          ; select tool 0

; currently volumetric extrusion is somehow broken in RRF
;M200 D[filament_diameter_0] T0 ; set filament diameter for volumetric E

M83                                         ; use relative distances for extrusion
G90                                         ; use absolute coordinates

; machine_mode / switch_checked are bit-flip hardened, read through "" ^ (see globals):
; "checked" only by exact match with "1431655765" (0x55555555)
if state.status == "simulating"
  if ("" ^ global.machine_mode) != "automatic"
    echo "Error: simulation requires automatic mode - close both doors and verify door switches first"
    M2
  ; confirm the guard (globals, "CONFIRMING") - a guard that is skipped protects nothing
  if ("" ^ global.machine_mode) != "automatic"
    echo "Error: automatic mode not confirmed on re-read - simulation aborted"
    M2
  M99

; Low-spool warning per tool from the slicer's filament estimate in the file header
; (job.file.filament[i] = slicer extruder i = tool i), converted to grams with that
; tool's filament diameter and the density recorded on its spool. One message for all
; tools - a second non-blocking M291 would replace the first. Warns only - never blocks,
; this runs unattended in automatic mode; the operator decides.
; Copy/mirror mode: the slicer lists one extruder that both tools extrude, so only tool
; 0 is checked here; the consumption tracker still books both spools (it reads the
; position of each extruder drive).
var low = ""
var need = 0.0
while iterations < min(#job.file.filament, 2)
  if global.spool_density[iterations] > 0
    set var.need = {job.file.filament[iterations] * pi * pow(global.filament_diameter[iterations] / 2, 2) * global.spool_density[iterations] / 1000}
    if var.need > global.spool_remaining[iterations]
      set var.low = var.low ^ "T" ^ iterations ^ " needs ~" ^ floor(var.need) ^ " g, has " ^ floor(global.spool_remaining[iterations]) ^ " g left. "
if var.low != ""
  M118 P0 S{"Warning: low spool - " ^ var.low}
  M291 R"Low spool" P{var.low} S1 T30

; (door_ignore_trigger removed - it was never read; the door triggers run off the pins)
while ("" ^ global.door_left_switch_checked) != "1431655765" || ("" ^ global.door_right_switch_checked) != "1431655765"
  if iterations > 5
    echo "Error: unable to verify the door switches! abort! - Contact the Manufacturer for Assistance!"
    M0
    M99

  if iterations > 0
    var links = (("" ^ global.door_left_switch_checked) == "1431655765") ? "geprüft" : "nicht geprüft"
    var rechts = (("" ^ global.door_right_switch_checked) == "1431655765") ? "geprüft" : "nicht geprüft"
    M291 P{"Öffnen Sie <b>beide</b> Türen zum Druckraum einmal<br>Türstatus links: " ^ var.links ^ "<br>Türstatus rechts: " ^ var.rechts}  R"Türkontrolle" S2
  else
    M291 P"Öffnen Sie <b>beide</b> Türen zum Druckraum einmal - und kontrollieren Sie dabei zugleich, dass der Druckraum sauber ist.<br/><b>Achtung:</b> die Druckplatte könnte heiß sein." R"Türkontrolle" S2

; Confirm the loop exit with the inverse comparison (globals, "CONFIRMING"): leaving the
; wait above is the permissive decision that lets this file heat and move, so both flags
; are read once more before it acts on them.
if ("" ^ global.door_left_switch_checked) != "1431655765" || ("" ^ global.door_right_switch_checked) != "1431655765"
  echo "Error: door switches not confirmed on re-read! abort!"
  M0
  M99

M116                                        ; wait for all heaters
M98 P"0:/sys/meltingplot/print/wait-for-heater.g" H0 ; wait for bed heater to settle

while ("" ^ global.machine_mode) != "automatic"
  G4 S1 ; wait for automatic mode
  if iterations > 10
    echo "Error: machine is not in automatic mode! abort!"
    M0
    M99

; confirm the loop exit, see above
if ("" ^ global.machine_mode) != "automatic"
  echo "Error: automatic mode not confirmed on re-read! abort!"
  M0
  M99

M400 ; dsf specific
G4 P500 ; dsf specific - wait for the keepout zone to remove

if move.axes[0].homed == false || move.axes[1].homed == false || move.axes[2].homed == false || move.axes[3].homed == false            ; check if u is homed
  M98 P"0:/macros/meltingplot/calibration/align-z-axis"
  G90 G1 Z50
  G4 S30 ; wait 30 s for heat to warmup the printhead / chamber temp sensor
  G28 ; G32 is part of homez.g
  if result != 0 || global.result != 0
    echo "Warning: G28 failed - repeat"
    G28
    if result != 0 || global.result != 0
      echo "Error: G28 failed - abort!"
      M99
else
  G90 G1 Z50
  G4 S30 ; wait 30 s for heat to warmup the printhead / chamber temp sensor
  G32 ; align bed
  if result != 0 || global.result != 0
    echo "Warning: G32 failed - run G28"
    G28
    if result != 0 || global.result != 0
      echo "Error: G28 failed - abort!"
      M99

G29                                         ; create new hight map
if result != 0 || global.result != 0
  echo "Warning: G29 failed - repeat"
  G32
  G29
  if result != 0 || global.result != 0
    echo "Error: G29 failed to create height map"
    M0
    M99

M106 S0
M98 P"0:/sys/meltingplot/print/prime-nozzle.g"    ; prime nozzle