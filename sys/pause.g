; pause.g
; called when a print from SD card is paused
;
if state.currentTool != -1
  set global.pause_extruder = tools[state.currentTool].extruders[0]   ; drive whose re-prime resume.g scales
  M83                                                                 ; relative extruder moves
  G10                                                                 ; retract move
  G1 E-12.5 F2000                                                     ; retract 12.5mm of filament
else
  set global.pause_extruder = -1                                      ; no tool -> resume.g keeps its full re-prime path off

if move.axes[2].homed
  var amount = 5
  if move.axes[2].machinePosition < 200
    set var.amount = 200
  G91 G1 Z{var.amount} F1200                                                     ; lift Z relative to current position

M106 S0                                                             ; disable fan
T-1 P0                                                              ; put current tool into standby without toolchange

G90
G53 G1 X{(move.axes[0].max-5)} Y{(move.axes[1].min)} U{(move.axes[3].max)} F60000
M400 ; sbc specific

; snapshot for resume.g: manual extrusion while paused is measured against this
if global.pause_extruder != -1
  set global.pause_extruder_pos = move.extruders[global.pause_extruder].position

; MFM auto-recovery runs HERE, before the pause commits: while pause.g executes the firmware
; state is "pausing" - M24 is ignored, M25 rejected and DWC greys out resume/jog/extrude on
; every channel. Run after the pause commits it is unprotected (2026-09-03: an operator resume
; was accepted mid-recovery, resume.g pulled the head from X min onto the part and the 25 mm
; purge plus the nozzle clean ran there - blob, Y collision). Tool select/deselect is ours,
; the recovery hands its verdict back in global.result.
if global.mfm_recovery_requested
  set global.mfm_recovery_requested = false
  T R1 P0                                                           ; restore point 1 is already saved when pause.g runs
  set global.result = 0
  M98 P"0:/sys/meltingplot/mfm_auto_recovery"
  set global.mfm_recovery_last_result = global.result               ; global.result is only valid right after the call
  T-1 P0                                                            ; back to standby; resume.g re-selects via T R1
