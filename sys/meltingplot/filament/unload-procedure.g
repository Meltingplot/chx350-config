; Daemon-initiated forced unload (broken-profile watchdog / failed-load cleanup):
; skip the physical unload so the daemon's M702 cannot block. Self-clear the
; one-shot flag here so it can never get stuck set. MUST stay first.
if global.filament_unload_skip
  set global.filament_unload_skip = false
  M99

if global.debug
  echo "filament/unload-procedure.g"

set global.result = 0 ; 0 = success, 1 = failure

M98 P"0:/sys/meltingplot/ce-declaration/doors/ensure-checked-closed.g"

if state.currentTool == -1
  echo "No tool selected - abort!"
  set global.result = 1
  M400 ; sbc specific
  M99

; remember the unload nozzle temperature - filament/load-procedure.g uses it to decide
; whether high-temp residue must be purged at elevated temperature on the next load
set global.last_filament_temp = tools[state.currentTool].active[0]
echo >"0:/sys/generated/last-filament-temp.g" "set global.last_filament_temp = " ^ global.last_filament_temp

if move.axes[0].homed == false || move.axes[1].homed == false || move.axes[3].homed == false
  G28 X ; home x axis -> will also home y and u axis
  if result != 0 || global.result != 0
    echo "Homing failed - abort!"
    set global.result = 1
    M400 ; sbc specific
    M99

; the z-height must be hight enough to allow the cleaner to raise 50mm
if move.axes[2].homed == true && move.axes[2].machinePosition < (move.axes[2].max - 55)
  G90 G1 Z{move.axes[2].max-55} ; raise printbed to the bottom to prevent damage while feeding filament

; this position is better suited to unfeed filament because the extruder is closer to the middle
; of the bed and the filament can be fed in straighter which is better for the filament sensors
G1 X300 Y0 F60000 ; move to the middle of the bed

M83                  ; relative extrusion

M17 E0               ; activate tool board motor! bug in 3.6.1

G1 E16 F120          ; extrude 12mm
G4 S5                ; wait 5 seconds for filament to soften

; Spool tracker: the retraction below books nothing. Most of it is filament that was
; never booked - fed by hand through the tube; the motor only fed the ~65 mm from the
; gear to the nozzle, and their molten end is cut off - so crediting it back would
; overstate the spool by 1-2 g per unload. Instead of a re-base at the end, the baseline
; is shifted by the retracted distance: whatever daemon.g books in between (it books at
; every extruder stop) is cancelled by the shift, in either order. G4 above has waited
; for the extrusion, so the position is settled.
var e = tools[state.currentTool].extruders[0]
var retract_from = move.extruders[var.e].position
G1 E-20 F300         ; retract 10mm @ 5mm/sec
G4 S5                ; wait 5 second for filament to harden
G1 E-100 F120        ; retract 100mm @ 2mm/sec
G1 E-100 F180        ; fast retract any additional filament
G4 P0                ; wait for moves to finish
M400                 ; wait for moves to finish
M291 P"Remove the Filament." S2
M291 P"Is the filament free? Press OK if yes, No to retract another 100mm." R"Filament Check" K{"Yes","No"} S4
if input != 0
  G1 E-100 F300        ; additional retract 100mm if filament is not free
  M400
set global.spool_track_baseline[state.currentTool] = global.spool_track_baseline[state.currentTool] + move.extruders[var.e].position - var.retract_from
M98 P"0:/sys/meltingplot/spool/track.g" W1   ; settle the booking and write it now
M98 P"0:/sys/meltingplot/nozzle-cleaner/clean.g"
M568 P{state.currentTool} A0 ; disable hotend
; tell the daemon.g watchdog that a physical unload actually ran - checked on the
; OM filament-name -> "" transition to detect unload.g files missing the standard line
set global.filament_unload_done = true
M400 ; sbc specific