; Z stall watchdog - expression trigger T5 (config.g, M581.1), a process function, not CE.
; Z homing runs the four Z motors into their stops. driver-stall.g flags each motor's stall,
; arms global.z_motor_stall_deadline at the first and sets z_motor_stall_complete once all
; four reported. RRF fires this trigger at every Z homing when the deadline has passed, and
; when it lies more than 30 s ahead (driver-stall.g arms at most 30 s ahead, so the value
; changed without it writing it). All four reported and the deadline plausible: disarm.
; Anything else halts - a motor that did not report keeps driving against its stop and
; breaks the bed's joints.
; Only this macro disarms. It runs while the expression is already true, so its write cannot
; fire T5 again; the reset driver-stall.g used to write landed between two lookups of the
; expression and fired it (config.g).
; The disarm is the permissive branch, confirmed by an inverse read (CLAUDE.md, "Bit-flip
; hardened states"): only driver-stall.g sets the flag and only this macro clears it, so a
; disagreement takes the halt. Nothing in front of an M112 may throw: the flag is a scalar
; read through the "" ^ coercion (an index into z_motor_stalled[] could throw), the message
; a plain concatenation.
if ("" ^ global.z_motor_stall_complete) == "1431655765" && global.z_motor_stall_deadline <= state.upTime + 30
  if ("" ^ global.z_motor_stall_complete) != "1431655765"
    echo "Error: Z stall watchdog - all Z motors reported, not confirmed on re-read - machine halt!"
    M98 P"0:/sys/meltingplot/lib/set-led-color.g" C"yellow" E1
    M112
  else
    ; deadline last: the next stall move waits for it (z-axis/align-motors.g), so it starts clear
    set global.z_motor_stalled = vector(4, 0xAAAAAAAA)
    set global.z_motor_stall_complete = 0xAAAAAAAA
    set global.z_motor_stall_deadline = 0
else
  echo "Error: Z stall watchdog (max " ^ global.z_motor_stall_time_max ^ " s, deadline " ^ global.z_motor_stall_deadline ^ ", upTime " ^ state.upTime ^ ") - not all Z motors reported their stall, or the deadline is corrupted - machine halt!"
  M98 P"0:/sys/meltingplot/lib/set-led-color.g" C"yellow" E1
  M112
