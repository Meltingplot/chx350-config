if global.debug
  echo "driver stall - "^{param.B}^"."^{param.D}^" : "^{param.P}^" ,"^{param.S}

; sensorless_z_homing, z_motor_stalled[] and z_motor_stall_complete are bit-flip hardened (see globals):
; 0x55555555 is the only value that counts, read through the "" ^ coercion as
; "1431655765". Any other value - including a corrupted one - is an unexpected stall.
if param.B == 0 && param.D < 4
  if ("" ^ global.sensorless_z_homing) == "1431655765"
    ; this will address double events from drivers
    set global.z_motor_stalled[param.D] = 0x55555555

    if global.z_motor_stall_deadline == 0
      ; trigger5.g halts on a deadline more than 30 s ahead, so a max outside 1..30 cannot
      ; be armed - it is either corrupted or misconfigured; arm the default instead
      if global.z_motor_stall_time_max >= 1 && global.z_motor_stall_time_max <= 30
        set global.z_motor_stall_deadline = state.upTime + global.z_motor_stall_time_max
      else
        echo "Warning: z_motor_stall_time_max is " ^ global.z_motor_stall_time_max ^ " - implausible, arming 5 s"
        set global.z_motor_stall_deadline = state.upTime + 5

    ; all four reported: trigger5.g disarms the watchdog when the deadline has passed. Never
    ; write the deadline here - a write between two lookups of T5's expression fires it
    ; (config.g); trigger5.g writes it while the expression is already true.
    if ("" ^ global.z_motor_stalled[0]) == "1431655765" && ("" ^ global.z_motor_stalled[1]) == "1431655765" && ("" ^ global.z_motor_stalled[2]) == "1431655765" && ("" ^ global.z_motor_stalled[3]) == "1431655765"
      set global.z_motor_stall_complete = 0x55555555

    ; when each Z motor's stall was handled, so a trigger5.g halt shows which motor came late
    ; and by how much. Event log only (L2 without P, DSF logs it at M929 S2 and keeps it out of
    ; the console). Last in the branch: nothing in front of the flag may throw. upTime and
    ; msUpTime are two reads, across a second rollover the time reads up to 1 s low.
    M118 S{"Z stall: driver " ^ param.D ^ " at " ^ state.upTime ^ "." ^ (state.msUpTime < 10 ? "00" : (state.msUpTime < 100 ? "0" : "")) ^ state.msUpTime ^ " s, deadline " ^ global.z_motor_stall_deadline} L2
  else
    echo "Z-Motor stall detected! E-Stop!"
    M112
