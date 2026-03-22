var last_axis_motion_time = vector(4, 0)
var last_extruder_motion_time = vector(2, 0)

while state.status != "halted" && global.daemon_reload == false
  var now = state.upTime + state.msUpTime / 1000

  while iterations < #global.axis_is_moving
    var diff = global.last_machine_position[iterations] - move.axes[iterations].machinePosition
    if var.diff != 0
      set global.axis_is_moving[iterations] = var.diff
      set var.last_axis_motion_time[iterations] = var.now
    elif (var.now - var.last_axis_motion_time[iterations]) >= 0.25
      set global.axis_is_moving[iterations] = 0

  while iterations < #move.extruders
    var diff = global.last_extruder_position[iterations] - move.extruders[iterations].position
    if var.diff != 0
      set global.extruder_is_moving[iterations] = var.diff
      set var.last_extruder_motion_time[iterations] = var.now
    elif (var.now - var.last_extruder_motion_time[iterations]) >= 0.25
      set global.extruder_is_moving[iterations] = 0

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

  ; === MFM monitoring — only during printing (calibration uses ignoreMFMevents separately) ===
  if state.status == "processing" && job.file.fileName != null

    ; Suppression expiry
    if global.mfm_suppress_until > 0 && state.upTime >= global.mfm_suppress_until
      set global.mfm_suppress_until = 0
      set global.ignoreMFMevents = false
      set global.mfm_last_pct = null
      if global.debug
        echo "MFM: suppression period ended, monitoring resumed"

    ; --- Heater PWM tracking (10s rolling window) ---
    if (state.upTime - global.mfm_pwm_window_start) > 10
      ; Window complete — save range and reset
      set global.mfm_pwm_range = global.mfm_pwm_max - global.mfm_pwm_min
      set global.mfm_pwm_min = heat.heaters[1].avgPwm
      set global.mfm_pwm_max = heat.heaters[1].avgPwm
      set global.mfm_pwm_window_start = state.upTime
    else
      set global.mfm_pwm_min = min(global.mfm_pwm_min, heat.heaters[1].avgPwm)
      set global.mfm_pwm_max = max(global.mfm_pwm_max, heat.heaters[1].avgPwm)

    ; --- Fixed 500ms time base for MFM checks ---
    if (var.now - global.mfm_last_check_time) >= 0.5
      set global.mfm_last_check_time = var.now

      if global.mfm_suppress_until == 0
        var currentPct = sensors.filamentMonitors[0].lastPercentage
        if var.currentPct != null && var.currentPct != global.mfm_last_pct
          ; New MFM reading arrived

          ; Backoff fast-track recovery
          if global.mfmbackoff < 3
            if var.currentPct > 80 && var.currentPct < 150
              if global.debug
                echo "MFM: reading normal (" ^ {var.currentPct} ^ "%) — fast-track speed restore"
              M220 S100
              set global.mfmbackoff = 3
              set global.lastMFMBackoffCheck = state.upTime
            elif (global.lastMFMBackoffCheck + 60) < state.upTime
              ; Slow recovery: step up speed every 60s (existing fallback)
              M220 S{50+25*global.mfmbackoff}
              set global.mfmbackoff = global.mfmbackoff + 1
              set global.lastMFMBackoffCheck = state.upTime

          ; Oscillation detection (swing-based)
          if global.mfm_last_pct != null
            ; Reset swing count if window has expired
            if (state.upTime - global.mfm_window_start) > 300
              set global.mfm_swing_count = 0
              set global.mfm_window_start = state.upTime
            var swing = abs(var.currentPct - global.mfm_last_pct)
            if var.swing >= 80
              if global.debug
                echo "MFM: large swing (" ^ {global.mfm_last_pct} ^ "% → " ^ {var.currentPct} ^ "%)"
              set global.mfm_swing_count = global.mfm_swing_count + 1
              if global.mfm_swing_count == 1
                ; Tier 1: brief suppression to cover measurement accumulation artifact
                set global.mfm_suppress_until = state.upTime + 15
                set global.ignoreMFMevents = true
                M220 S100
                set global.mfmbackoff = 3
              elif global.mfm_swing_count >= 2
                ; Tier 2: sustained oscillation — long suppression
                if global.debug
                  echo "MFM: oscillation detected — suppressing for 60s"
                set global.mfm_suppress_until = state.upTime + 60
                set global.ignoreMFMevents = true
                set global.mfm_swing_count = 0
                M220 S100
                set global.mfmbackoff = 3

          set global.mfm_last_pct = var.currentPct

  elif global.mfmbackoff < 3 && ((global.lastMFMBackoffCheck + 60) < state.upTime)
    ; Fallback: original slow recovery when not printing (e.g. recovering after print state change)
    M220 S{50+25*global.mfmbackoff}
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

  set global.daemon_cycle_time = state.upTime + state.msUpTime/1000 - var.now
  G4 P100 ; wait 100ms

if global.debug
  echo "Daemon reloading"

set global.daemon_reload = false