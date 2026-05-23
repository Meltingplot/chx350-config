; --- Script-scope persistent state ---
; Config cache (n_*, tool_heater_idx) is refreshed periodically inside the
; loop, not at script start — daemon may begin executing before config.g
; finishes initializing tools/heaters. Vectors are over-sized (max 8) so
; their declaration doesn't depend on runtime values.
var n_axes = 0
var n_extruders = 0
var n_tools = 0
var tool_heater_idx = vector(8, 1)
var config_last_refresh = 0
var last_axis_motion_time = vector(8, 0)
var last_extruder_motion_time = vector(8, 0)

while state.status != "halted" && global.daemon_reload == false
  ; === Per-iteration Point-in-Time snapshot ===
  ; Each `state.X` / `move.X` / `heat.X` / `sensors.X` / `tools.X` and each
  ; `global.X` access in SBC mode is an SPI RTT. Snapshot them once at loop
  ; entry; downstream logic reads from var.* only. Writes go to global.X AND
  ; sync to var.X so the snapshot stays consistent for later reads.
  var t = state.upTime
  var now = var.t + state.msUpTime / 1000

  ; --- Refresh config cache every 30s (also on first iteration) ---
  ; Topology rarely changes at runtime; periodic refresh tolerates a late
  ; config.g without paying the RTT cost every loop.
  if var.config_last_refresh == 0 || (var.t - var.config_last_refresh) >= 30
    set var.n_axes = #global.axis_is_moving
    set var.n_extruders = #move.extruders
    set var.n_tools = #tools
    while iterations < var.n_tools
      set var.tool_heater_idx[iterations] = tools[iterations].heaters[0]
    set var.config_last_refresh = var.t

  var status = state.status
  var job_name = job.file.fileName
  var gpIn2 = sensors.gpIn[2].value
  var gpIn3 = sensors.gpIn[3].value
  var bed_state = heat.heaters[0].state
  var bed_current = heat.heaters[0].current
  var hotend_current = heat.heaters[1].current
  var ambient = sensors.analog[4].lastReading
  var first_filament = move.extruders[0].filament

  var axis_pos = vector(var.n_axes, 0.0)
  while iterations < var.n_axes
    set var.axis_pos[iterations] = move.axes[iterations].machinePosition
  var extruder_pos = vector(var.n_extruders, 0.0)
  while iterations < var.n_extruders
    set var.extruder_pos[iterations] = move.extruders[iterations].position
  var tool_heater_state = vector(var.n_tools, "off")
  while iterations < var.n_tools
    set var.tool_heater_state[iterations] = heat.heaters[var.tool_heater_idx[iterations]].state

  ; Hot globals (read multiple times per iteration)
  var door_left_open = global.door_left_open
  var door_right_open = global.door_right_open
  var door_left_state_transition = global.door_left_state_transition
  var door_right_state_transition = global.door_right_state_transition
  var machine_mode = global.machine_mode
  var idle_since = global.idle_since
  var idle_hotend_done = global.idle_hotend_cutoff_done
  var idle_bed_done = global.idle_bed_cutoff_done
  var idle_hotend_to = global.idle_hotend_timeout
  var idle_bed_to = global.idle_bed_timeout
  var z_stall_time = global.z_motor_stall_time
  var z_stall_max = global.z_motor_stall_time_max
  var debug = global.debug
  var filament_loading_error = global.filament_loading_error

  var last_axis_pos_global = vector(var.n_axes, 0.0)
  while iterations < var.n_axes
    set var.last_axis_pos_global[iterations] = global.last_machine_position[iterations]
  var last_extruder_pos_global = vector(var.n_extruders, 0.0)
  while iterations < var.n_extruders
    set var.last_extruder_pos_global[iterations] = global.last_extruder_position[iterations]
  var axis_is_moving = vector(var.n_axes, 0)
  while iterations < var.n_axes
    set var.axis_is_moving[iterations] = global.axis_is_moving[iterations]
  var extruder_is_moving = vector(var.n_extruders, 0)
  while iterations < var.n_extruders
    set var.extruder_is_moving[iterations] = global.extruder_is_moving[iterations]

  ; --- Motion detection ---
  while iterations < var.n_axes
    var diff = var.last_axis_pos_global[iterations] - var.axis_pos[iterations]
    if var.diff != 0
      set var.axis_is_moving[iterations] = var.diff
      set var.last_axis_motion_time[iterations] = var.now
    elif (var.now - var.last_axis_motion_time[iterations]) >= 0.25
      set var.axis_is_moving[iterations] = 0
  while iterations < var.n_extruders
    var diff = var.last_extruder_pos_global[iterations] - var.extruder_pos[iterations]
    if var.diff != 0
      set var.extruder_is_moving[iterations] = var.diff
      set var.last_extruder_motion_time[iterations] = var.now
    elif (var.now - var.last_extruder_motion_time[iterations]) >= 0.25
      set var.extruder_is_moving[iterations] = 0

  ; --- Doors: write to global only on transition (no per-iter no-op writes) ---
  if var.gpIn2 == 0 && var.door_left_open == false
    set global.door_left_open = true
    set var.door_left_open = true
    set global.door_left_state_transition = true
    set var.door_left_state_transition = true
    set global.door_left_switch_checked = true
  elif var.gpIn2 != 0 && var.door_left_open == true
    set global.door_left_open = false
    set var.door_left_open = false
    set global.door_left_state_transition = true
    set var.door_left_state_transition = true
  elif var.door_left_state_transition
    set global.door_left_state_transition = false
    set var.door_left_state_transition = false

  if var.gpIn3 == 0 && var.door_right_open == false
    set global.door_right_open = true
    set var.door_right_open = true
    set global.door_right_state_transition = true
    set var.door_right_state_transition = true
    set global.door_right_switch_checked = true
  elif var.gpIn3 != 0 && var.door_right_open == true
    set global.door_right_open = false
    set var.door_right_open = false
    set global.door_right_state_transition = true
    set var.door_right_state_transition = true
  elif var.door_right_state_transition
    set global.door_right_state_transition = false
    set var.door_right_state_transition = false

  var motion_detected = (var.axis_is_moving[0] != 0 || var.axis_is_moving[1] != 0 || var.axis_is_moving[2] != 0 || var.axis_is_moving[3] != 0 || var.extruder_is_moving[0] != 0 || var.extruder_is_moving[1] != 0)
  set global.potential_unsafe_state = var.motion_detected

  if (var.bed_current > 50 || var.hotend_current > 50 || var.ambient > 50)
    set global.machine_is_hot = true
  else
    set global.machine_is_hot = false

  ; === Idle heater cutoff ===
  if var.idle_since == 0
    set global.idle_since = var.t
    set var.idle_since = var.t

  var is_active = (var.status == "processing") || var.motion_detected
  if var.is_active
    set global.idle_since = var.t
    set var.idle_since = var.t
    if var.idle_hotend_done || var.idle_bed_done
      set global.idle_hotend_cutoff_done = false
      set global.idle_bed_cutoff_done = false
      set var.idle_hotend_done = false
      set var.idle_bed_done = false

  var idle_duration = var.t - var.idle_since
  var paused_with_job = (var.status == "paused" && var.job_name != null)

  ; Hotend cutoff — applies to both idle and paused-with-job
  if var.idle_duration >= var.idle_hotend_to && var.idle_hotend_done == false
    var any_hotend_on = false
    while iterations < var.n_tools
      if var.tool_heater_state[iterations] != "off"
        set var.any_hotend_on = true
    if var.any_hotend_on
      echo "Idle cutoff: hotends off after " ^ {floor(var.idle_duration/60)} ^ " min idle"
      while iterations < var.n_tools
        M568 P{iterations} A0
    set global.idle_hotend_cutoff_done = true
    set var.idle_hotend_done = true

  ; Bed cutoff — only when truly idle, NEVER when paused with active job
  if var.idle_duration >= var.idle_bed_to && var.idle_bed_done == false && var.paused_with_job == false
    if var.bed_state != "off"
      echo "Idle cutoff: bed off after " ^ {floor(var.idle_duration/60)} ^ " min idle"
      M140 P0 S-273.15
    set global.idle_bed_cutoff_done = true
    set var.idle_bed_done = true

  if var.filament_loading_error == true && var.first_filament != ""
    M702 P0
    set global.filament_loading_error = false

  if var.z_stall_time > 0 && (var.t > var.z_stall_time)
    echo "Error: faild to home all z-motors within " ^ var.z_stall_max ^ "s - abort!"
    M98 P"0:/sys/meltingplot/set_led_color" C"yellow" E1
    M112

  ; === MFM monitoring — only during printing (calibration uses ignoreMFMevents separately) ===
  if var.status == "processing" && var.job_name != null
    ; MFM sub-snapshot — only fetched when block is actually active
    var avgPwm = heat.heaters[1].avgPwm
    var mfm_suppress_until = global.mfm_suppress_until
    var mfm_last_pct = global.mfm_last_pct
    var mfm_error_ref = global.mfm_error_extruder_ref
    var mfm_normal_since = global.mfm_normal_since
    var mfm_window_start = global.mfm_window_start
    var mfm_swing_count = global.mfm_swing_count
    var mfm_pwm_min = global.mfm_pwm_min
    var mfm_pwm_max = global.mfm_pwm_max
    var mfm_pwm_window_start = global.mfm_pwm_window_start
    var mfmbackoff = global.mfmbackoff
    var last_mfm_check = global.lastMFMBackoffCheck
    var mfm_last_check_time = global.mfm_last_check_time

    ; Suppression expiry
    if var.mfm_suppress_until > 0 && var.t >= var.mfm_suppress_until
      set global.mfm_suppress_until = 0
      set var.mfm_suppress_until = 0
      set global.ignoreMFMevents = false
      set global.mfm_last_pct = null
      set var.mfm_last_pct = null
      if var.debug
        echo "MFM: suppression period ended, monitoring resumed"

    ; --- Heater PWM tracking (10s rolling window) ---
    if (var.t - var.mfm_pwm_window_start) > 10
      set global.mfm_pwm_range = var.mfm_pwm_max - var.mfm_pwm_min
      set global.mfm_pwm_min = var.avgPwm
      set var.mfm_pwm_min = var.avgPwm
      set global.mfm_pwm_max = var.avgPwm
      set var.mfm_pwm_max = var.avgPwm
      set global.mfm_pwm_window_start = var.t
      set var.mfm_pwm_window_start = var.t
    else
      var new_min = min(var.mfm_pwm_min, var.avgPwm)
      var new_max = max(var.mfm_pwm_max, var.avgPwm)
      set global.mfm_pwm_min = var.new_min
      set var.mfm_pwm_min = var.new_min
      set global.mfm_pwm_max = var.new_max
      set var.mfm_pwm_max = var.new_max

    ; --- Fixed 500ms time base for MFM checks ---
    if (var.now - var.mfm_last_check_time) >= 0.5
      set global.mfm_last_check_time = var.now
      set var.mfm_last_check_time = var.now

      if var.mfm_suppress_until == 0
        var currentPct = sensors.filamentMonitors[0].lastPercentage
        if var.currentPct != null && var.currentPct != var.mfm_last_pct

          ; Backoff fast-track recovery
          if var.mfmbackoff < 3
            if var.currentPct > 80 && var.currentPct < 150
              if var.debug
                echo "MFM: reading normal (" ^ {var.currentPct} ^ "%) — fast-track speed restore"
              M220 S100
              set global.mfmbackoff = 3
              set var.mfmbackoff = 3
              set global.lastMFMBackoffCheck = var.t
              set var.last_mfm_check = var.t
            elif (var.last_mfm_check + 60) < var.t
              M220 S{50+25*var.mfmbackoff}
              set global.mfmbackoff = var.mfmbackoff + 1
              set var.mfmbackoff = var.mfmbackoff + 1
              set global.lastMFMBackoffCheck = var.t
              set var.last_mfm_check = var.t

          ; Sustained normal tracking — clear error distance after 30s of clean readings
          if var.mfm_error_ref != null
            if var.currentPct > 80 && var.currentPct < 150
              if var.mfm_normal_since == 0
                set global.mfm_normal_since = var.t
                set var.mfm_normal_since = var.t
              elif (var.t - var.mfm_normal_since) >= 30
                if var.debug
                  echo "MFM: 30s sustained normal — error tracking cleared"
                set global.mfm_error_extruder_ref = null
                set var.mfm_error_ref = null
                set global.mfm_normal_since = 0
                set var.mfm_normal_since = 0
            else
              set global.mfm_normal_since = 0
              set var.mfm_normal_since = 0

          ; Oscillation detection (swing-based)
          if var.mfm_last_pct != null
            if (var.t - var.mfm_window_start) > 300
              set global.mfm_swing_count = 0
              set var.mfm_swing_count = 0
              set global.mfm_window_start = var.t
              set var.mfm_window_start = var.t
            var swing = abs(var.currentPct - var.mfm_last_pct)
            if var.swing >= 80
              if var.debug
                echo "MFM: large swing (" ^ {var.mfm_last_pct} ^ "% → " ^ {var.currentPct} ^ "%)"
              set global.mfm_swing_count = var.mfm_swing_count + 1
              set var.mfm_swing_count = var.mfm_swing_count + 1
              set global.mfm_normal_since = 0
              set var.mfm_normal_since = 0
              if var.mfm_swing_count == 1
                ; Tier 1: brief suppression to cover measurement accumulation artifact
                set global.mfm_suppress_until = var.t + 15
                set var.mfm_suppress_until = var.t + 15
                set global.ignoreMFMevents = true
                M220 S100
                set global.mfmbackoff = 3
                set var.mfmbackoff = 3
              elif var.mfm_swing_count >= 2
                ; Tier 2: sustained oscillation — long suppression
                if var.debug
                  echo "MFM: oscillation detected — suppressing for 60s"
                set global.mfm_suppress_until = var.t + 60
                set var.mfm_suppress_until = var.t + 60
                set global.ignoreMFMevents = true
                set global.mfm_swing_count = 0
                set var.mfm_swing_count = 0
                M220 S100
                set global.mfmbackoff = 3
                set var.mfmbackoff = 3

          set global.mfm_last_pct = var.currentPct
          set var.mfm_last_pct = var.currentPct

  elif global.mfmbackoff < 3 && ((global.lastMFMBackoffCheck + 60) < var.t)
    ; Fallback: original slow recovery when not printing (e.g. recovering after print state change)
    M220 S{50+25*global.mfmbackoff}
    set global.mfmbackoff = global.mfmbackoff + 1
    set global.lastMFMBackoffCheck = var.t

  if (var.door_left_open == false && var.door_right_open == false && global.door_left_switch_checked == true && global.door_right_switch_checked == true)
    if var.machine_mode != "automatic"
      M98 P"0:/sys/meltingplot/ce-declaration/operating-mode/automatic.g"
  elif var.machine_mode != "default"
    if var.motion_detected
      echo "Error: potential unsafe state in default mode detected - machine halt!"
      M98 P"0:/sys/meltingplot/set_led_color" C"yellow" E1
      M112

    M98 P"0:/sys/meltingplot/ce-declaration/operating-mode/default.g"

  ; led logic — global.machine_is_hot was just written, read directly (1 RTT)
  if global.machine_is_hot && var.machine_mode != "automatic"
    M98 P"0:/sys/meltingplot/set_led_color" C"red"
  elif var.machine_mode == "automatic"
    if var.job_name == null
      M98 P"0:/sys/meltingplot/set_led_color" C"green"
    else
      M98 P"0:/sys/meltingplot/set_led_color" C"white"
  else
    M98 P"0:/sys/meltingplot/set_led_color" C"blue"

  ; --- Writeback of motion arrays (bulk write, no re-read) ---
  while iterations < var.n_axes
    set global.axis_is_moving[iterations] = var.axis_is_moving[iterations]
  while iterations < var.n_extruders
    set global.extruder_is_moving[iterations] = var.extruder_is_moving[iterations]

  ; --- Writeback of position arrays (use snapshot, no re-read) ---
  while iterations < var.n_extruders
    set global.last_extruder_position[iterations] = var.extruder_pos[iterations]
  while iterations < var.n_axes
    set global.last_machine_position[iterations] = var.axis_pos[iterations]

  ; Cycle-time measurement: fresh OM reads (this IS the measurement point)
  set global.daemon_cycle_time = state.upTime + state.msUpTime/1000 - var.now
  G4 P100 ; wait 100ms

if global.debug
  echo "Daemon reloading"

set global.daemon_reload = false
