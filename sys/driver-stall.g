if global.debug
  echo "driver stall - "^{param.B}^"."^{param.D}^" : "^{param.P}^" ,"^{param.S}

; sensorless_z_homing and z_motor_stalled[] are bit-flip hardened (see globals):
; 0x55555555 is the only value that counts, read through the "" ^ coercion as
; "1431655765". Any other value - including a corrupted one - is an unexpected stall.
if param.B == 0 && param.D < 4
  if ("" ^ global.sensorless_z_homing) == "1431655765"
    ; this will address double events from drivers
    set global.z_motor_stalled[param.D] = 0x55555555

    if global.z_motor_stall_deadline == 0
      ; daemon.g halts on a deadline more than 30 s ahead, so a max outside 1..30 cannot
      ; be armed - it is either corrupted or misconfigured; arm the default instead
      if global.z_motor_stall_time_max >= 1 && global.z_motor_stall_time_max <= 30
        set global.z_motor_stall_deadline = state.upTime + global.z_motor_stall_time_max
      else
        echo "Warning: z_motor_stall_time_max is " ^ global.z_motor_stall_time_max ^ " - implausible, arming 5 s"
        set global.z_motor_stall_deadline = state.upTime + 5

    if ("" ^ global.z_motor_stalled[0]) == "1431655765" && ("" ^ global.z_motor_stalled[1]) == "1431655765" && ("" ^ global.z_motor_stalled[2]) == "1431655765" && ("" ^ global.z_motor_stalled[3]) == "1431655765"
      set global.z_motor_stall_deadline = 0 ; reset timer
      set global.z_motor_stalled = vector(4, 0xAAAAAAAA) ; reset counter
  else
    echo "Z-Motor stall detected! E-Stop!"
    M112
