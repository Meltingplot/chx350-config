echo "driver stall - "^{param.B}^"."^{param.D}^" : "^{param.P}^" ,"^{param.S}

if param.B == 0 && param.D < 4
  if global.sensorless_z_homing
    ; this will address double events from drivers 
    set global.z_motor_stall_count[param.D] = 1
    
    if global.z_motor_stall_time == 0
      set global.z_motor_stall_time = state.upTime + global.z_motor_stall_time_max

    if global.z_motor_stall_count[0] == 1 && global.z_motor_stall_count[1] == 1 && global.z_motor_stall_count[2] == 1 && global.z_motor_stall_count[3] == 1
      set global.z_motor_stall_time = 0 ; reset timer
      set global.z_motor_stall_count = vector(4,0) ; reset counter
  else
    echo "Z-Motor stall detected! E-Stop!"
    M112
    