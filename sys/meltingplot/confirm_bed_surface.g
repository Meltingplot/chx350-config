; confirm_bed_surface.g
; Asks which build plate surface is installed, as a dropdown with the configured one
; preselected, and persists a change in global.bed_surface and
; sys/generated/bed-surface.g (machine-local state, see globals). Machine-wide: the
; CHX350 has one bed.
;   M98 P"0:/sys/meltingplot/confirm_bed_surface.g"
; Cancelling keeps the configured value - J2 (result = -1, execution continues), never
; J1. Called by macro set-bed-surface.
; The key list must stay in step with the K list of the M291 below (same order).

if global.debug
  echo "confirm_bed_surface.g"

var keys = {"pei", "pei-textured", "pertinax", "g10", "carbon", "glass", "other"}

; preselect the configured surface; "unknown" or an off-list key preselects the first entry
var choice = 0
while iterations < #var.keys
  if var.keys[iterations] == global.bed_surface
    set var.choice = iterations
    break

M291 R"Build plate" P"Which build plate surface is installed?" S4 K{"PEI smooth","PEI textured","Pertinax (Hartpapier)","G10 fiberglass (Glasfaser)","Carbon fibre","Glass","Other"} F{var.choice} J2
if result != 0             ; J2 leaves input undefined - result must be tested right here
  M99
var key = var.keys[input]

if var.key == global.bed_surface
  M99                      ; confirmed unchanged - nothing to persist

set global.bed_surface = var.key

var file = "0:/sys/generated/bed-surface.g"
echo >{var.file} "; build plate surface - written by confirm_bed_surface.g, do not edit"
echo >>{var.file} "set global.bed_surface = """ ^ var.key ^ """"

M118 P0 S{"Build plate surface set to " ^ var.key}
