; Z stall watchdog - expression trigger T5 (config.g, M581.1), a process function, not CE.
; Z homing runs the four Z motors into their stops; driver-stall.g counts the stalls and
; arms global.z_motor_stall_deadline. RRF fires this trigger when the deadline has passed
; (not all four motors reported - one keeps driving against its stop and breaks the
; bed's joints) or lies more than 30 s ahead (driver-stall.g arms at most 30 s ahead, so
; the value changed without it writing it).
; Halts unconditionally: the condition held when RRF fired, and a halt is never confirmed
; into a permissive outcome (CLAUDE.md, "Bit-flip hardened states"). The message is a
; plain concatenation on purpose - nothing in front of the M112 may throw.
echo "Error: Z stall watchdog (max " ^ global.z_motor_stall_time_max ^ " s, deadline " ^ global.z_motor_stall_deadline ^ ", upTime " ^ state.upTime ^ ") - not all Z motors reported their stall, or the deadline is corrupted - machine halt!"
M98 P"0:/sys/meltingplot/lib/set-led-color.g" C"yellow" E1
M112
