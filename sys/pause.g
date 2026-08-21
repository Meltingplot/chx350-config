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
