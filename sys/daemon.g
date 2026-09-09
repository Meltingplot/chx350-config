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
; filament-profile watchdog: last seen OM filament name + warn deadline (0 = disarmed).
; Initializing from the OM makes a boot with restored filament produce no change event.
var fil_prev = move.extruders[0].filament
var fil_watch_until = 0

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

  ; Idle is explicit: only "idle" and "paused" let the idle timer run. Every other state
  ; (processing, busy, changingTool, pausing, resuming, ...) is activity and resets it -
  ; enumerating the active states instead missed "resuming" and cut the bed off during
  ; resume.g after a long pause (2026-09-08).
  if (state.status != "idle" && state.status != "paused") || global.potential_unsafe_state
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
    elif (state.upTime - global.idle_since) >= global.idle_heater_timeout[iterations] && (global.idle_heater_pause_hold[iterations] == false || state.status == "idle")
      if heat.heaters[iterations].state != "off"
        echo "Idle cutoff: heater " ^ {iterations} ^ " off after " ^ {floor((state.upTime - global.idle_since)/60)} ^ " min idle"
        if iterations == 0
          M140 P0 S-273.15
        else
          M568 P{iterations - 1} A0
      set global.idle_heater_cutoff_done[iterations] = true

  if global.filament_loading_error == true && move.extruders[0].filament != ""
    ; the physical unload already ran in load_filament_sensorless' error paths (all of
    ; them call unload_filament, which sets filament_physical_unload_done) - so just
    ; drop the assignment: M702 P0 clears the loaded-filament name WITHOUT running
    ; unload.g, so it cannot block the daemon
    M702 P0
    set global.filament_loading_error = false

  ; --- filament-profile watchdog: detect profiles missing the standard load/unload lines ---
  ; A DWC-created profile without them fails SILENTLY: M701 registers the filament in the
  ; OM but nothing is ever physically loaded. fileread() cannot parse G-code files, so
  ; detection is behavioral: within 60s of a filament-name change either the physical load
  ; must have been dispatched (marker set by load_filament_sensorless_conditionally.g) or
  ; the profile is broken (DWC sends the consuming M703 within ~1s of M701, so 60s is
  ; generous). On a broken profile the daemon force-unloads to compel operator intervention:
  ; filament_forced_unload makes unload.g return immediately (and self-clears there), so the
  ; M702 only clears the assignment and cannot block this loop. No M98/blocking commands here.
  if move.extruders[0].filament != var.fil_prev
    if move.extruders[0].filament == ""
      ; unload: warn if no physical unload ran (unload.g missing the standard line). A
      ; daemon-forced unload sets filament_physical_unload_done itself, so this stays
      ; quiet after the broken-profile force-unload below.
      if global.filament_physical_unload_done == false
        M291 S1 T0 R"Filament profile broken" P{"Profile '" ^ var.fil_prev ^ "': filament was unregistered but never physically unloaded - unload.g is missing the standard line, see console."}
        M118 P0 S{"Filament profile '" ^ var.fil_prev ^ "' broken: unload.g did not run the shared filament_unload.g - run macro repair-filament-profile"}
      set global.filament_physical_load_name = ""
      set var.fil_watch_until = 0
    else
      set var.fil_watch_until = var.now + 60
      set global.filament_physical_unload_done = false
    set var.fil_prev = move.extruders[0].filament
  if var.fil_watch_until != 0
    if global.filament_physical_load_name == var.fil_prev
      set var.fil_watch_until = 0 ; physical load dispatched - failures beyond this point raise filament_loading_error
    elif var.now >= var.fil_watch_until
      set var.fil_watch_until = 0
      set global.filament_broken_profile = var.fil_prev
      if global.deferred_filament_load[0]
        ; load.g armed the deferred flag but nothing consumed it -> config.g misses the hook (or M703 was never sent)
        set global.deferred_filament_load[0] = false
        M291 S1 T0 R"Filament profile broken" P{"Profile '" ^ var.fil_prev ^ "': physical load never started - config.g is missing the standard hook. Filament was unregistered, run macro repair-filament-profile, then load again."}
        M118 P0 S{"Filament profile '" ^ var.fil_prev ^ "' broken: config.g never ran the deferred-load hook - run macro repair-filament-profile, then load again"}
      else
        ; the deferred flag was never armed -> load.g is missing the standard line
        M291 S1 T0 R"Filament profile broken" P{"Profile '" ^ var.fil_prev ^ "': filament was registered but never physically loaded - load.g is missing the standard line. Filament was unregistered, see console."}
        M118 P0 S{"Filament profile '" ^ var.fil_prev ^ "' broken: load.g did not run the shared filament_load.g - run macro repair-filament-profile"}
      ; nothing was physically loaded (broken profile), so mark the unload handled -
      ; this suppresses the "unload.g broken" check when M702 clears the name next
      ; iteration. filament_forced_unload self-clears inside the M702's unload.g.
      set global.filament_physical_unload_done = true
      set global.filament_forced_unload = true
      M702

  if global.z_motor_stall_time > 0 && state.upTime > global.z_motor_stall_time
    echo "Error: failed to home all z-motors within " ^ global.z_motor_stall_time_max ^ "s - abort!"
    M98 P"0:/sys/meltingplot/set_led_color" C"yellow" E1
    M112

  ; melt-zone peak for resume.g's re-prime: highest extruder position reached by manual
  ; moves while paused (purge beyond it leaves the nozzle, retraction after it is the
  ; real deficit). Only in "paused" - during "pausing" the MFM recovery's own purge runs,
  ; and mfm_auto_recovery re-snapshots afterwards. Single OM read, non-blocking.
  if state.status == "paused" && global.pause_extruder != -1
    set global.pause_extruder_peak = max(global.pause_extruder_peak, move.extruders[global.pause_extruder].position)

  if state.status == "processing" && job.file.fileName != null
    if global.mfm_suppress_until > 0 && var.now >= global.mfm_suppress_until
      set global.mfm_suppress_until = 0
      set global.ignoreMFMevents = false
      set global.mfm_last_pct = null
      if global.debug
        echo "MFM: suppression period ended, monitoring resumed"
    ; --- Systematic flow-bias (e-steps) detection — WARN ONLY, never apply from the daemon ---
    ; avgPercentage is the toolboard's whole-print integral (only restarts when the monitor goes
    ; idle on pause/stop), so it is robust to a momentary awkward section (many short moves the MFM
    ; reads poorly). Act only on a SETTLED, time-sustained drift, NOT at a fixed distance: avg must
    ; stay outside the ±3% deadband AND flat (within ±3% of the window reference) for the whole
    ; sustain window; any move >3% restarts the window (filters a progressing fault), any in-deadband
    ; sample clears it. One warning per print. NOTE: the correction MUST NOT be applied here — M92
    ; calls LockAllMovementSystemsAndWaitForStandstill and would freeze the whole daemon (and all its
    ; safety checks) until motion stops, then fire a false unsafe-state M112 on the stale-state resume.
    ; Only NON-blocking commands are allowed in daemon.g. The operator recalibrates via the e-steps macro.
    if global.mfm_esteps_done == false && (var.now - global.mfm_esteps_check_time) >= 60
      set global.mfm_esteps_check_time = var.now
      ; cache avg for atomicity — used in the gate, the math, and the message
      var avg = sensors.filamentMonitors[0].avgPercentage
      ; mfmbackoff != 3 ⇒ speed is reduced, which itself depresses the reading — that avg is not a
      ; valid flow-bias sample, so clear the drift window and only accumulate drift at full speed.
      if var.avg == null || global.mfmbackoff != 3 || (var.avg >= 97 && var.avg <= 103)
        set global.mfm_esteps_drift_since = 0
      elif global.mfm_esteps_drift_since == 0 || abs(var.avg - global.mfm_esteps_drift_avg) > 3
        ; (re)start the settle window: drift just began, or avg is still moving (not settled)
        set global.mfm_esteps_drift_since = var.now
        set global.mfm_esteps_drift_avg = var.avg
      elif (var.now - global.mfm_esteps_drift_since) >= 600
        ; avg has been outside the deadband AND flat for the full window → settled systematic bias.
        ; Compute the bounded (±5% absolute vs current e-steps) target. It is NOT applied here —
        ; M92 blocks (forbidden in daemon.g). filament-error.g applies it at standstill on the next
        ; MFM error pause. Stepping is unchanged at detection time, so stepsPerMm IS the baseline.
        var base = move.extruders[0].stepsPerMm
        var lo = {var.base * 0.95}
        var hi = {var.base * 1.05}
        var ideal = {var.base * 100 / var.avg}
        set global.mfm_esteps_suggested = max(var.lo, min(var.hi, var.ideal))
        set global.mfm_esteps_done = true
        M118 P3 S{"MFM flow bias " ^ var.avg ^ "% - recalibrate e-steps to ~" ^ global.mfm_esteps_suggested}
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
        if global.mfmbackoff < 3 && var.pct > 80 && var.pct < 150
          ; reading recovered on its own → restore full speed early (the unconditional
          ; time-based restore below is the fallback that breaks the reduced-speed deadlock)
          if global.debug
            echo "MFM: reading normal (" ^ {var.pct} ^ "%) — fast-track speed restore"
          M220 S100
          set global.mfmbackoff = 3
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
    ; Unconditional time-based speed restore (replaces the reading-gated stepped ramp). Reduced
    ; speed itself depresses the MFM reading, so waiting for the reading to recover deadlocks the
    ; restore — jump straight back to 100% a fixed time after the last backoff, regardless of the
    ; (depressed) reading. Runs every cycle, independent of the 0.5s sampling gate.
    if global.mfmbackoff < 3 && (var.now - global.lastMFMBackoffCheck) >= 30
      M220 S100
      set global.mfmbackoff = 3
      set global.lastMFMBackoffCheck = var.now
  elif global.mfmbackoff < 3
    ; not printing — restore full speed immediately, ready for the next job
    M220 S100
    set global.mfmbackoff = 3
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
