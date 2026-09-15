; homeall.g
; called to home all axes
;

set global.result = 0

M98 P"0:/sys/meltingplot/ensure_safety"

M98 P"0:/sys/meltingplot/align_z_axis.g"

M98 P"0:/sys/homex.g"                     ; squares the beam and homes Y and U on it, see homex.g
M98 P"0:/sys/homez.g"                     ; home z as well to ensure position is correct
