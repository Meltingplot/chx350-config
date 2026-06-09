; Daemon — background loop. SBC SPI cost model: every var/global/OM access
; is an SPI RTT. var.* caches do NOT save RTTs (same cost as direct reads)
; and add create+delete overhead. Read OM/globals directly; only declare a
; local var when atomicity across multiple lines is required.
var now = 0
; Daemon-private switch_checked mirror — globals are exposed via DWC and can
; be manually set to true to fake-trigger automatic mode; script-vars cannot.
; Daemon flips var to true ONLY on a real door-open edge. Mismatch with global
; clears both to false: unauthorized upgrade reverted, legitimate downgrade
; (e.g. print_end resetting to false) accepted in the same step.
var left_checked = global.door_left_switch_checked
var right_checked = global.door_right_switch_checked

while state.status != "halted" && global.daemon_reload == false
  set var.now = state.upTime + state.msUpTime/1000

  set global.potential_unsafe_state = false
  while iterations < #move.axes
    if global.last_machine_position[iterations] != move.axes[iterations].machinePosition
      set global.axis_is_moving[iterations] = global.last_machine_position[iterations] - move.axes[iterations].machinePosition
      set global.last_machine_position[iterations] = move.axes[iterations].machinePosition
      set global.last_axis_motion_time[iterations] = var.now
      set global.potential_unsafe_state = true
    elif (var.now - global.last_axis_motion_time[iterations]) < 0.25
      set global.potential_unsafe_state = true
    else
      set global.axis_is_moving[iterations] = 0
  while iterations < #move.extruders
    if global.last_extruder_position[iterations] != move.extruders[iterations].position
      set global.extruder_is_moving[iterations] = global.last_extruder_position[iterations] - move.extruders[iterations].position
      set global.last_extruder_position[iterations] = move.extruders[iterations].position
      set global.last_extruder_motion_time[iterations] = var.now
      set global.potential_unsafe_state = true
    elif (var.now - global.last_extruder_motion_time[iterations]) < 0.25
      set global.potential_unsafe_state = true
    else
      set global.extruder_is_moving[iterations] = 0

  if sensors.gpIn[2].value == 0 && global.door_left_open == false
    set global.door_left_open = true
    set global.door_left_state_transition = true
    set global.door_left_switch_checked = true
    set var.left_checked = true
  elif sensors.gpIn[2].value != 0 && global.door_left_open == true
    set global.door_left_open = false
    set global.door_left_state_transition = true
  elif global.door_left_state_transition
    set global.door_left_state_transition = false

  if sensors.gpIn[3].value == 0 && global.door_right_open == false
    set global.door_right_open = true
    set global.door_right_state_transition = true
    set global.door_right_switch_checked = true
    set var.right_checked = true
  elif sensors.gpIn[3].value != 0 && global.door_right_open == true
    set global.door_right_open = false
    set global.door_right_state_transition = true
  elif global.door_right_state_transition
    set global.door_right_state_transition = false

  if global.door_left_switch_checked != var.left_checked
    set global.door_left_switch_checked = false
    set var.left_checked = false
  if global.door_right_switch_checked != var.right_checked
    set global.door_right_switch_checked = false
    set var.right_checked = false

  set global.machine_is_hot = (heat.heaters[0].current > 50 || heat.heaters[1].current > 50 || sensors.analog[4].lastReading > 50)

  if state.status == "processing" || state.status == "busy" || state.status == "changingTool" || global.potential_unsafe_state
    set global.idle_since = state.upTime
    while iterations < #global.idle_heater_cutoff_done
      set global.idle_heater_cutoff_done[iterations] = false

  ; Per-heater idle cutoff. The off-command sets the heater STATE to off but leaves the
  ; active setpoint untouched (M568 A is required-state 0=off, not a temperature; M140
  ; S-273.15 drives the setpoint negative). So re-enable is detected via .state != "off",
  ; NOT .active — which keeps its old setpoint after cutoff and would re-arm every cycle,
  ; resetting the shared idle_since and starving longer-timeout heaters. Reading .state is
  ; gated behind the done-flag, so it costs nothing during normal operation. The only
  ; heater-type distinction is the off-command itself (no generic per-index heater-off
  ; M-code exists): heater 0 = bed (M140), heaters 1..#tools = tool heaters (M568 on tool h-1).
  while iterations < #global.idle_heater_timeout
    if global.idle_heater_cutoff_done[iterations]
      if heat.heaters[iterations].state != "off"
        set global.idle_since = state.upTime
        set global.idle_heater_cutoff_done[iterations] = false
    elif (state.upTime - global.idle_since) >= global.idle_heater_timeout[iterations] && (global.idle_heater_pause_hold[iterations] == false || state.status != "paused" || job.file.fileName == null)
      if heat.heaters[iterations].state != "off"
        echo "Idle cutoff: heater " ^ {iterations} ^ " off after " ^ {floor((state.upTime - global.idle_since)/60)} ^ " min idle"
        if iterations == 0
          M140 P0 S-273.15
        else
          M568 P{iterations - 1} A0
      set global.idle_heater_cutoff_done[iterations] = true

  if global.filament_loading_error == true && move.extruders[0].filament != ""
    M702 P0
    set global.filament_loading_error = false

  if global.z_motor_stall_time > 0 && state.upTime > global.z_motor_stall_time
    echo "Error: failed to home all z-motors within " ^ global.z_motor_stall_time_max ^ "s - abort!"
    M98 P"0:/sys/meltingplot/set_led_color" C"yellow" E1
    M112

  if state.status == "processing" && job.file.fileName != null
    if global.mfm_suppress_until > 0 && var.now >= global.mfm_suppress_until
      set global.mfm_suppress_until = 0
      set global.ignoreMFMevents = false
      set global.mfm_last_pct = null
      if global.debug
        echo "MFM: suppression period ended, monitoring resumed"
    ; --- Systematic flow-bias (e-steps) one-shot adaptive re-center, ±5% absolute vs baseline ---
    ; avgPercentage is the toolboard's whole-print integral (only restarts when the monitor goes
    ; idle on pause/stop), so it is robust to a momentary awkward section (many short moves the MFM
    ; reads poorly) and lags after correction — we therefore do NOT chase it back to 100%. Act only
    ; on a SETTLED, time-sustained drift, NOT at a fixed distance: avg must stay outside the ±3%
    ; deadband AND flat (within ±3% of the window's reference) for the whole sustain window; any
    ; move >3% restarts the window (filters a progressing fault, which should pause not compensate),
    ; any in-deadband sample clears it. One bounded correction per print, clamped vs the captured
    ; baseline (no ratcheting). print_end restores the baseline. The per-segment lastPercentage
    ; (the actual P=4/P=5 trigger) normalises right after the M92, even though avg keeps lagging.
    if global.mfm_esteps_done == false && (var.now - global.mfm_esteps_check_time) >= 60
      set global.mfm_esteps_check_time = var.now
      ; cache avg for atomicity — used in the gate, the math, and the messages
      var avg = sensors.filamentMonitors[0].avgPercentage
      if var.avg == null || (var.avg >= 97 && var.avg <= 103)
        set global.mfm_esteps_drift_since = 0
      elif global.mfm_esteps_drift_since == 0 || abs(var.avg - global.mfm_esteps_drift_avg) > 3
        ; (re)start the settle window: drift just began, or avg is still moving (not settled)
        set global.mfm_esteps_drift_since = var.now
        set global.mfm_esteps_drift_avg = var.avg
      elif (var.now - global.mfm_esteps_drift_since) >= 600
        ; avg has been outside the deadband AND flat for the full window → settled systematic bias
        if global.mfm_esteps_baseline == 0
          set global.mfm_esteps_baseline = move.extruders[0].stepsPerMm
        var lo = {global.mfm_esteps_baseline * 0.95}
        var hi = {global.mfm_esteps_baseline * 1.05}
        var ideal = {global.mfm_esteps_baseline * 100 / var.avg}
        var clamped = max(var.lo, min(var.hi, var.ideal))
        M92 E{var.clamped}
        set global.mfm_esteps_done = true
        echo "MFM: sustained flow bias avg=" ^ var.avg ^ "% — e-steps " ^ global.mfm_esteps_baseline ^ " -> " ^ var.clamped
        if var.ideal < var.lo || var.ideal > var.hi
          M291 P{"MFM: Flow seit >10min systematisch bei " ^ var.avg ^ "% — Korrektur auf ±5% begrenzt, e-steps auf " ^ var.clamped ^ " gesetzt. Wahrscheinlich echter e-steps-/Sensitivity-Fehler — bitte e-steps neu kalibrieren."} R"MFM Flow-Bias" S1 T0
        else
          M291 P{"MFM: Flow seit >10min systematisch bei " ^ var.avg ^ "% — e-steps adaptiv auf " ^ var.clamped ^ " angepasst (innerhalb ±5%). Zur Sicherheit e-steps manuell kalibrieren."} R"MFM Flow-Bias" S1 T0
    if (var.now - global.mfm_pwm_window_start) > 10
      set global.mfm_pwm_range = global.mfm_pwm_max - global.mfm_pwm_min
      set global.mfm_pwm_min = heat.heaters[1].avgPwm
      set global.mfm_pwm_max = heat.heaters[1].avgPwm
      set global.mfm_pwm_window_start = var.now
    else
      set global.mfm_pwm_min = min(global.mfm_pwm_min, heat.heaters[1].avgPwm)
      set global.mfm_pwm_max = max(global.mfm_pwm_max, heat.heaters[1].avgPwm)
    if (var.now - global.mfm_last_check_time) >= 0.5 && global.mfm_suppress_until == 0
      set global.mfm_last_check_time = var.now
      ; var.pct cached for atomicity — branches/writeback all need same value
      var pct = sensors.filamentMonitors[0].lastPercentage
      if var.pct != null && var.pct != global.mfm_last_pct
        if global.mfmbackoff < 3
          if var.pct > 80 && var.pct < 150
            if global.debug
              echo "MFM: reading normal (" ^ {var.pct} ^ "%) — fast-track speed restore"
            M220 S100
            set global.mfmbackoff = 3
            set global.lastMFMBackoffCheck = var.now
          elif (global.lastMFMBackoffCheck + 60) < var.now
            M220 S{50+25*global.mfmbackoff}
            set global.mfmbackoff = global.mfmbackoff + 1
            set global.lastMFMBackoffCheck = var.now
        if global.mfm_error_extruder_ref != null
          if var.pct > 80 && var.pct < 150
            if global.mfm_normal_since == 0
              set global.mfm_normal_since = var.now
            elif (var.now - global.mfm_normal_since) >= 30
              if global.debug
                echo "MFM: 30s sustained normal — error tracking cleared"
              set global.mfm_error_extruder_ref = null
              set global.mfm_normal_since = 0
          else
            set global.mfm_normal_since = 0
        if global.mfm_last_pct != null
          if (var.now - global.mfm_window_start) > 300
            set global.mfm_swing_count = 0
            set global.mfm_window_start = var.now
          if abs(var.pct - global.mfm_last_pct) >= 80
            if global.debug
              echo "MFM: large swing (" ^ {global.mfm_last_pct} ^ "% → " ^ {var.pct} ^ "%)"
            set global.mfm_swing_count = global.mfm_swing_count + 1
            set global.mfm_normal_since = 0
            if global.mfm_swing_count == 1
              set global.mfm_suppress_until = var.now + 15
              set global.ignoreMFMevents = true
              M220 S100
              set global.mfmbackoff = 3
            elif global.mfm_swing_count >= 2
              if global.debug
                echo "MFM: oscillation detected — suppressing for 60s"
              set global.mfm_suppress_until = var.now + 60
              set global.ignoreMFMevents = true
              set global.mfm_swing_count = 0
              M220 S100
              set global.mfmbackoff = 3
        set global.mfm_last_pct = var.pct
  elif global.mfmbackoff < 3 && (global.lastMFMBackoffCheck + 60) < var.now
    M220 S{50+25*global.mfmbackoff}
    set global.mfmbackoff = global.mfmbackoff + 1
    set global.lastMFMBackoffCheck = var.now

  if global.door_left_open == false && global.door_right_open == false && global.door_left_switch_checked == true && global.door_right_switch_checked == true
    if global.machine_mode != "automatic"
      M98 P"0:/sys/meltingplot/ce-declaration/operating-mode/automatic.g"
  elif global.machine_mode != "default"
    if global.potential_unsafe_state
      echo "Error: potential unsafe state in default mode detected - machine halt!"
      M98 P"0:/sys/meltingplot/set_led_color" C"yellow" E1
      M112
    M98 P"0:/sys/meltingplot/ce-declaration/operating-mode/default.g"

  if global.machine_is_hot && global.machine_mode != "automatic"
    if global.led_color != 4
      M98 P"0:/sys/meltingplot/set_led_color" C"red"
  elif state.status == "paused" && global.potential_unsafe_state == false
    M98 P"0:/sys/meltingplot/set_led_color" C"pulse_white"
  elif global.machine_mode == "automatic"
    if job.file.fileName == null
      if global.led_color != 2
        M98 P"0:/sys/meltingplot/set_led_color" C"green"
    elif global.led_color != 0
      M98 P"0:/sys/meltingplot/set_led_color" C"white"
  elif global.led_color != 1
    M98 P"0:/sys/meltingplot/set_led_color" C"blue"

  set global.daemon_cycle_time = state.upTime + state.msUpTime/1000 - var.now
  G4 P100

if global.debug
  echo "Daemon reloading"
set global.daemon_reload = false
