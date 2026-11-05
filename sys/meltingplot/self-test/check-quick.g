; self-test/check-quick.g
; Quick tier of the self-test (CLAUDE.md, "Power-on self-test"), after every boot and every
; self_test_interval[0] hours of operation: reads the object model, moves and heats nothing.
; Two passes one machine tick (10 s) apart: only a second look tells whether daemon.g still loops.
; The scanning probe is not checked here. Whether it reads valid depends on its drive current and
; on the distance to the bed (z-probe/scan-contact.g), and the bed can stand anywhere after a boot,
; so an invalid reading (999999, 0) is no sign of a defect. Its board counts under the CAN boards,
; and every Z homing uses the probe in its real configuration: the monthly tier homes.
; Everything that refuses a job goes into global.self_test_found, what only affects the quality
; of a print is a warning in the console and the event log. The limits come from the object
; model history of the lab machine (QA journal 2026-10-03, 9 h job + idle): vIn 24.0 V on the
; main board and the toolboard (22.8 V under heater load), 48.5-48.8 V on the 1HCL boards, 5.0 V
; on the SZP board; v12 11.9-12.3 V; MCU up to 66 C on the toolboard.
; The reads are guarded where a config.g that ended early would leave them null: this file has
; to reach its report then, the startup error is what the operator must see.
; Called by self-test/tick.g on the Trigger channel: reads, set, M118 and M291 S1 only.

if global.self_test_step == 0
  ; daemon.g overwrites its cycle time at the end of every iteration (about 100 ms)
  set global.daemon_cycle_time = -1
  set global.self_test_step = 1
else
  ; --- machine not fit for a job: goes into the list ---

  if global.daemon_cycle_time == -1
    set global.self_test_found = global.self_test_found ^ "daemon.g steht; "

  ; first error while config.g ran, kept by DSF: such an error may have ended config.g early
  ; exists(), not != null: an SBC field holding an object reaches the firmware as the text {object},
  ; so that comparison throws exactly when there is an error to report (DSF Expressions.cs)
  if exists(state.startupError.file)
    set global.self_test_found = global.self_test_found ^ "Fehler beim Start: " ^ state.startupError.file ^ " Zeile " ^ state.startupError.line ^ "; "

  ; boards[0] is the main board, which has no state (Platform.cpp)
  while iterations < #boards
    var address = boards[iterations].canAddress
    if iterations > 0
      if boards[iterations].state != "running"
        set global.self_test_found = global.self_test_found ^ "Platine " ^ var.address ^ ": " ^ boards[iterations].state ^ "; "
    ; +-10 % of the rail the board hangs on (CLAUDE.md, "Hardware Topology")
    var rail = (var.address >= 50 && var.address <= 53) ? 48 : ((var.address == 60) ? 5 : 24)
    if boards[iterations].vIn != null
      if abs(boards[iterations].vIn.current - var.rail) > var.rail / 10
        set global.self_test_found = global.self_test_found ^ "Platine " ^ var.address ^ ": VIN " ^ boards[iterations].vIn.current ^ " V; "
    if boards[iterations].v12 != null
      if abs(boards[iterations].v12.current - 12) > 1
        set global.self_test_found = global.self_test_found ^ "Platine " ^ var.address ^ ": 12 V bei " ^ boards[iterations].v12.current ^ " V; "
    if boards[iterations].mcuTemp != null
      if boards[iterations].mcuTemp.current > 75
        M118 P0 L1 S{"Warning: self-test: board " ^ var.address ^ " MCU at " ^ boards[iterations].mcuTemp.current ^ " C"}

  ; state covers open and short circuit (a reading of 2000 C), the range a sensor out of its wits
  while iterations < #sensors.analog
    if sensors.analog[iterations] != null
      if sensors.analog[iterations].state != "ok" || sensors.analog[iterations].lastReading < 0 || sensors.analog[iterations].lastReading > 320
        set global.self_test_found = global.self_test_found ^ "Sensor " ^ sensors.analog[iterations].name ^ ": " ^ sensors.analog[iterations].state ^ ", " ^ sensors.analog[iterations].lastReading ^ " C; "

  ; The coil sits between bed and nozzle, so it cannot be much hotter than both. A frozen reading
  ; looks like that (2026-10-04: 55.42 C with the bed at 24 C and the nozzle at 29 C) and selects
  ; the warm Z calibration on a cold probe.
  if #sensors.analog > 4 && #heat.heaters > 1
    if sensors.analog[4] != null && heat.heaters[0] != null && heat.heaters[1] != null
      if sensors.analog[4].lastReading > max(heat.heaters[0].current, heat.heaters[1].current) + 15
        set global.self_test_found = global.self_test_found ^ "Sensor " ^ sensors.analog[4].name ^ " unplausibel: " ^ sensors.analog[4].lastReading ^ " C; "

  while iterations < #heat.heaters
    if heat.heaters[iterations] != null
      if heat.heaters[iterations].state == "fault" || heat.heaters[iterations].state == "offline"
        set global.self_test_found = global.self_test_found ^ "Heizung " ^ iterations ^ ": " ^ heat.heaters[iterations].state ^ "; "

  ; the machine tick has sampled these for 50 s by now (fan/check-coolant.g)
  while iterations < #global.fan_stalled
    set global.self_test_found = global.self_test_found ^ "Lüfter steht: " ^ fans[global.fan_stalled[iterations]].name ^ "; "

  ; the operator found the emergency stop dead in a monthly check (3: and its new test is armed)
  if global.self_test_estop_state == 2 || global.self_test_estop_state == 3
    set global.self_test_found = global.self_test_found ^ "NOT-HALT hat nicht ausgelöst; "

  ; --- only a warning: a print is possible, its quality is at risk ---

  ; "noFilament" and the movement errors are no fault of the monitor
  while iterations < #sensors.filamentMonitors
    if sensors.filamentMonitors[iterations] != null
      if sensors.filamentMonitors[iterations].status == "noDataReceived" || sensors.filamentMonitors[iterations].status == "sensorError"
        M118 P0 L1 S{"Warning: self-test: filament monitor " ^ iterations ^ " reports " ^ sensors.filamentMonitors[iterations].status}

  ; Free space of the writable mount that holds sys, and of no other. DSF lists every mount, and on
  ; the image the read-only ones report 0 although there is room: "/" and the plugin mounts read 0,
  ; /opt/dsf/sd/sys 24.8 GB (QA journal 2026-10-03). So volumes[0] says nothing, and neither does
  ; the smallest value. A machine without that mount, not on the image, keeps sys on "/".
  var mount = -1
  while iterations < #volumes
    if volumes[iterations].path == "/opt/dsf/sd/sys"
      set var.mount = iterations
      break
    elif volumes[iterations].path == "/"
      set var.mount = iterations
  if var.mount >= 0
    if volumes[var.mount].freeSpace != null
      if volumes[var.mount].freeSpace < 1000000000
        M118 P0 L1 S{"Warning: self-test: only " ^ floor(volumes[var.mount].freeSpace / 1000000) ^ " MB left on " ^ volumes[var.mount].path}

  M98 P"0:/sys/meltingplot/self-test/report.g" T0
