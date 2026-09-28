; timelapse/take-photo.g
; Takes one timelapse photo in the middle of a print. Called by the slicer's timelapse G-code at
; every layer change: retracts, lifts Z, moves the beam out of the camera's view, takes the photo
; and returns to the print where it left off. It pauses inline, not with M25 - pause.g and
; resume.g (heater standby, 12.5 mm retract, re-prime) do not run, and restore point 1 is untouched.
; An M98 from the job is not pausable, so a pause requested meanwhile waits until it returned.

if state.status == "simulating"
  M99

G60 S3                                              ; print position to restore point 3 (1 = pause, 2 = tool change)

; G10 is idempotent: after a slicer G10 it does nothing, and the G11 below leaves the slicer's
; own G11 nothing to do. G10 also applies the tool's Z hop, which RRF keeps as a tool offset,
; so the return to the restore point's Z lands one hop high and the G11 takes it off again.
; The extra 2 mm on top keeps the parked nozzle from oozing, whatever M207 retracts.
var retract = state.currentTool != -1
if var.retract
  M83                                               ; relative extruder moves
  G10                                               ; firmware retract (M207 of the loaded filament)
  G1 E-2 F2000                                      ; plus 2 mm

; The camera looks from the X min side and the beam spans the whole depth, so a beam standing in X
; beyond everything printed so far hides nothing, wherever Y and U are: the beam only moves past the
; parts' X max. RRF keeps a bounding box per labelled object (job.build.objects[].x, whole mm), grown
; by the end point of every extruding move inside it; OrcaSlicer labels them ("; printing object").
; The clearance covers the head's overhang towards X min. Without labels, pause.g's park position.
var clearance = 100
var x_parts = -1                                    ; X max of everything printed so far, -1 = unknown
if job.build != null
  while iterations < #job.build.objects
    if job.build.objects[iterations].x[1] != null   ; null until the object has extruded
      set var.x_parts = max(var.x_parts, job.build.objects[iterations].x[1])

G91
G1 Z2 F1200                                         ; lift Z clear of the part
G90
if var.x_parts < 0
  G53 G1 X{move.axes[0].max - 5} Y{move.axes[1].min} U{move.axes[3].max} F60000   ; pause.g's park position
else
  G1 X{min(var.x_parts + var.clearance, move.axes[0].max - 5)} F60000   ; beam just beyond the parts
M400                                                ; the photo waits for the head to stand still
G4 P1000                                            ; compensate the capture delay
M240                                                ; take the photo (sys/M240.g), blocks until it is taken

G1 R3 X0 Y0 U0 F60000                               ; back above the print position
G1 R3 Z0 F1200                                      ; down to the print height
if var.retract
  G1 E2 F2000                                       ; the extra 2 mm back
  G11                                               ; unretract, drops the Z hop
