; homeall.g
; called to home all axes
;

; no homing while config.g runs - see CLAUDE.md, "Homing only after the start"
if state.status == "starting"
  abort "Error: homing refused - the machine is still starting (config.g)"

set global.result = 0

M98 P"0:/sys/meltingplot/ensure_safety"

M98 P"0:/sys/meltingplot/align_z_axis.g"

M98 P"0:/sys/homex.g"                                                 ; home x as well to ensure position is correct
if move.axes[1].homed == false            ; check if y is homed
  M98 P"0:/sys/homey.g"                   ; home y axis
if move.axes[3].homed == false            ; check if u is homed
  M98 P"0:/sys/homeu.g"                   ; home u axis
M98 P"0:/sys/homez.g"                                                 ; home z as well to ensure position is correct
