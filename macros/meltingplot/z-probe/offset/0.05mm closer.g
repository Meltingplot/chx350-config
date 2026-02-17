var current_z_offset = sensors.probes[0].offsets[2]
var new_z_offset = var.current_z_offset - 0.05

G31 K0 Z{var.new_z_offset*-1} ; set new z offset
echo "Z Offset updated. Current: " ^ var.current_z_offset ^ ", New: " ^ sensors.probes[0].offsets[2]
M500 P31 ; store new z offset