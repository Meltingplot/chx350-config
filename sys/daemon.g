var pause_grace_time = 0

while state.status != "halted" && global.daemon_reload == false
  var start_time = state.upTime + state.msUpTime / 1000

  while iterations < #global.axis_is_moving
    var diff = global.last_machine_position[iterations] - move.axes[iterations].machinePosition
    set global.axis_is_moving[iterations] = var.diff

  while iterations < #move.extruders
    var diff = global.last_extruder_position[iterations] - move.extruders[iterations].position
    set global.extruder_is_moving[iterations] = var.diff

  if sensors.gpIn[2].value == 0
    if global.door_left_open == false
      set global.door_left_open = true
      set global.door_left_state_transition = true
      set global.door_left_switch_checked = true
    else
      set global.door_left_state_transition = false
  else
    if global.door_left_open == true
      set global.door_left_open = false
      set global.door_left_state_transition = true
    else
      set global.door_left_state_transition = false

  if sensors.gpIn[3].value == 0
    if global.door_right_open == false
      set global.door_right_open = true
      set global.door_right_state_transition = true
      set global.door_right_switch_checked = true
    else
      set global.door_right_state_transition = false
  else
    if global.door_right_open == true
      set global.door_right_open = false
      set global.door_right_state_transition = true
    else
      set global.door_right_state_transition = false

  var motion_detected = ( global.axis_is_moving[0] != 0 || global.axis_is_moving[1] != 0 || global.axis_is_moving[2] != 0 || global.axis_is_moving[3] != 0 || global.extruder_is_moving[0] != 0 || global.extruder_is_moving[1] != 0 )
  if var.motion_detected
    set global.potential_unsafe_state = true
  else
    set global.potential_unsafe_state = false

  if (heat.heaters[0].current > 50 || heat.heaters[1].current > 50 || sensors.analog[4].lastReading > 50)
    set global.machine_is_hot = true
  else
    set global.machine_is_hot = false

  if global.filament_loading_error == true && move.extruders[0].filament != ""
    M702 P0
    set global.filament_loading_error = false

  if global.z_motor_stall_time > 0 && (state.upTime > global.z_motor_stall_time)
    echo "Error: faild to home all z-motors within " ^ global.z_motor_stall_time_max ^ "s - abort!"
    M98 P"0:/sys/meltingplot/set_led_color" C"yellow" E1
    M112

  if exists(global.mfmbackoff) && exists(global.lastMFMBackoffCheck) && global.mfmbackoff < 3 && ((global.lastMFMBackoffCheck + 60) < state.upTime)
    M220 S{50+25*global.mfmbackoff} ; increase speed in steps of 50 + 0*25, 1*25 2*25
    set global.mfmbackoff = global.mfmbackoff + 1
    set global.lastMFMBackoffCheck = state.upTime

  if(global.door_left_open == false && global.door_right_open == false && global.door_left_switch_checked == true && global.door_right_switch_checked == true)
    if global.machine_mode != "automatic"
      M98 P"0:/sys/meltingplot/ce-declaration/operating-mode/automatic.g"
  elif global.machine_mode != "default"
    ; the mode switch from automatic to default must be instantaneously, if it is not possible due to current motion, halt the machine 
    if global.potential_unsafe_state == true
      echo "Error: potential unsafe state in default mode detected - machine halt!"
      M98 P"0:/sys/meltingplot/set_led_color" C"yellow" E1
      M112

    M98 P"0:/sys/meltingplot/ce-declaration/operating-mode/default.g"

  ; led logic
  if global.machine_is_hot && global.machine_mode != "automatic"
    M98 P"0:/sys/meltingplot/set_led_color" C"red"
  elif global.machine_mode == "automatic"
    if job.file.fileName == null
      M98 P"0:/sys/meltingplot/set_led_color" C"green"
    else
      M98 P"0:/sys/meltingplot/set_led_color" C"white"
  else
    M98 P"0:/sys/meltingplot/set_led_color" C"blue"

  while iterations < #move.extruders
    set global.last_extruder_position[iterations] = move.extruders[iterations].position

  while iterations < #global.last_machine_position
    set global.last_machine_position[iterations] = move.axes[iterations].machinePosition

  set global.daemon_cycle_time = state.upTime + state.msUpTime/1000 - var.start_time
  G4 P100 ; wait 100ms

if global.debug
  echo "Daemon reloading"

set global.daemon_reload = false