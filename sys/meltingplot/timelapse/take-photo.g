; timelapse/take-photo.g
; Takes one timelapse photo in the middle of a print. Called by the slicer's timelapse G-code at
; every layer change: retracts, lifts Z, parks beam and heads at the job's fixed photo position,
; takes the photo and returns to the print where it left off. It pauses inline, not with M25 -
; pause.g and resume.g (heater standby, 12.5 mm retract, re-prime) do not run, and restore point 1
; is untouched.
; An M98 from the job is not pausable, so a pause requested meanwhile waits until it returned.

if state.status == "simulating"
  M99

M400                                                ; finish the layer: the queue then holds only the moves below
G60 S3                                              ; print position to restore point 3 (1 = pause, 2 = tool change)

; Z: 2 mm above the layer, but never below the highest park position of the job (reset by
; start.g). In sequential printing ("by object") the objects printed before stand taller than the
; current layer: each had a photo at its last layer change, so the highest park position is 2 mm
; above that layer, more than a layer height above the object's top. Machine coordinates, read at
; rest (M400 above), like the G53 moves below; the profiles' M207 Z hop (at most 0.6 mm) stays
; below the 2 mm, so this move always goes up.
set global.timelapse_park_z = min(max(move.axes[2].machinePosition + 2, global.timelapse_park_z), move.axes[2].max)

; The photos of a job are compared with each other, so the beam and both heads stand in the same
; place in every one of them: Y and U in their end positions (pause.g's park position), the beam in
; X beyond everything printed so far - the camera looks from the X min side and the beam spans the
; whole depth. RRF keeps a bounding box per labelled object (job.build.objects[].x, whole mm, user
; coordinates - tool offset 0, so they equal the machine coordinates of the G53 move below), grown by
; the end point of every extruding move inside it; OrcaSlicer labels them ("; printing object").
; The clearance covers the head's overhang towards X min. The job's park X (reset by start.g) gets
; the margin on top and moves back only once the parts have grown into it, so it stays the same
; over many layers. Without labels, or before anything was printed, pause.g's park position.
var clearance = 100
var margin = 50
var x_parts = -1                                    ; X max of everything printed so far, -1 = unknown
if job.build != null
  while iterations < #job.build.objects
    if job.build.objects[iterations].x[1] != null   ; null until the object has extruded
      set var.x_parts = max(var.x_parts, job.build.objects[iterations].x[1])
var park_x = move.axes[0].max - 5                   ; pause.g's park position
if var.x_parts >= 0
  if var.x_parts + var.clearance > global.timelapse_park_x   ; first photo, or the parts grew into the margin
    set global.timelapse_park_x = min(var.x_parts + var.clearance + var.margin, var.park_x)
  set var.park_x = global.timelapse_park_x

; G10 is idempotent: after the slicer's G10 (OrcaSlicer retracts at the layer change, right
; before this call) it does nothing, and the G11 below leaves the slicer's own G11 nothing to do.
; The extra 0.8 mm on top keep the parked nozzle from oozing, whatever M207 retracts, and go back
; in before the G11. G10 also applies the tool's Z hop, which RRF keeps as a tool offset, so the
; return to the restore point's Z lands one hop high and the G11 takes it off again.
G10                                                 ; firmware retract (M207 of the loaded filament)
G90
G53 G1 Z{global.timelapse_park_z} F1200            ; first up, clear of everything printed in this job
G53 G1 X{var.park_x} Y{move.axes[1].min} U{move.axes[3].max} F60000   ; then beam behind the parts, heads in their end positions
; RRF starts sys/M240.g at once, without waiting for the moves above: a camera that needs the beam
; at rest waits for it there (M400).
M240                                                ; take the photo (sys/M240.g), blocks until it is taken

G1 R3 X0 Y0 U0 F60000                               ; back above the print position, still at the park height
G1 R3 Z0 F1200                                      ; down to the print height
G11                                                 ; unretract, drops the Z hop
