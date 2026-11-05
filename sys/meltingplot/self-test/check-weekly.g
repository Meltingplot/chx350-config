; self-test/check-weekly.g
; Weekly tier of the self-test (CLAUDE.md, "Power-on self-test"), every self_test_interval[1]
; hours of operation: does every heater heat, does every fan with a tacho turn? No motion and no
; operator, and the temperatures stay below the 50 C that default mode allows (operating-mode/
; default.g), so it may run right after a boot, before anyone checked the doors.
; A state machine, one step per machine tick (10 s), because this runs on the Trigger channel,
; where trigger4.g waits behind it: a G4 or a wait here would hold up the door interlock.
;   step 0  ready? Doors closed, every heater off, machine cold, operator fans at 0, every tool's
;           setpoint within its limit. If not, the tier stays due and tick.g looks again. Then
;           start the heaters and the fans.
;   step 1  fans: read the tachos, fans off
;   step 2  wait for the heaters. Bed: 3 C rise in 240 s. Hotend: 44 C in 90 s, then one tick
;           longer, because above 40 C the thermostat has to start the radiators (config.g)
; Per heater (heater 0 = bed, heater h = tool h-1, as the idle cutoff in daemon.g):
; self_test_heater_state[h] 0 heating, 1 at target, 2 finished. Someone else taking a heater over
; or a door opening ends the run without a verdict, and a job does the same (tick.g passes A1):
; the tier stays due.
; The setpoint limit in step 0: a tool keeps its filament's temperature while its heater is off,
; and with default mode's 50 C cap the test could not give it back (self-test/stop-heater.g). It
; waits for automatic mode then. Only the active setpoint changes, the standby one stays.

var aborted = exists(param.A)
var elapsed = state.upTime - global.self_test_since

if global.self_test_step == 0
  var ready = sensors.gpIn[2].value == 1 && sensors.gpIn[3].value == 1
  while iterations <= #tools
    if heat.heaters[iterations].state != "off" || heat.heaters[iterations].current > ((iterations == 0) ? 40 : 35)
      set var.ready = false
    elif iterations > 0
      if tools[iterations - 1].active[0] >= heat.heaters[iterations].max
        set var.ready = false
  while iterations < #global.fan_adjustable
    if fans[global.fan_adjustable[iterations]].requestedValue != 0
      set var.ready = false
  if !var.ready
    set global.self_test_run = -1
    set global.self_test_manual = -1
  else
    set global.self_test_step = 1
    while iterations <= #tools
      set global.self_test_heater_state[iterations] = 0
      if iterations == 0
        set global.self_test_heater_target[0] = ceil(heat.heaters[0].current) + 4
        M140 P0 S{global.self_test_heater_target[0]}
      else
        set global.self_test_saved_active[iterations] = tools[iterations - 1].active[0]
        set global.self_test_heater_target[iterations] = 45
        M568 P{iterations - 1} S45 A2
    while iterations < #global.fan_adjustable
      M106 P{global.fan_adjustable[iterations]} S1
elif !var.aborted
  var finished = true

  if sensors.gpIn[2].value != 1 || sensors.gpIn[3].value != 1
    set var.aborted = true

  if global.self_test_step == 1
    ; fans 0-3 follow the slicer's numbering, 4 and up are the water loop (below). Fan 1 turns
    ; with fan 0's PWM, fans without a tacho read -1. A thermostat that does not drive its fan
    ; (actualValue 0, fan 1 with the hotend below 10 C) says nothing about the fan.
    while iterations < min(#fans, 4)
      if fans[iterations] != null
        if fans[iterations].rpm == 0 && fans[iterations].actualValue > 0
          set global.self_test_found = global.self_test_found ^ "Lüfter steht: " ^ fans[iterations].name ^ "; "
    while iterations < #global.fan_adjustable
      M106 P{global.fan_adjustable[iterations]} S0
    set global.self_test_step = 2

  while iterations <= #tools
    if global.self_test_heater_state[iterations] < 2
      var off = false
      if heat.heaters[iterations].state == "fault"
        set global.self_test_found = global.self_test_found ^ "Heizung " ^ iterations ^ ": Fehler beim Heizen; "
        set var.off = true
      elif heat.heaters[iterations].state != "active" || heat.heaters[iterations].active != global.self_test_heater_target[iterations]
        set var.aborted = true
      elif global.self_test_heater_state[iterations] == 1
        ; the thermostat of the water loop's fans reads the hotend of tool 0 (config.g)
        if iterations == 1
          while iterations < #fans - 4
            if fans[iterations + 4] != null
              if fans[iterations + 4].rpm == 0
                set global.self_test_found = global.self_test_found ^ "Lüfter steht: " ^ fans[iterations + 4].name ^ "; "
        set var.off = true
      elif heat.heaters[iterations].current >= global.self_test_heater_target[iterations] - 1
        if iterations == 0
          set var.off = true
        else
          set global.self_test_heater_state[iterations] = 1
      elif var.elapsed > ((iterations == 0) ? 240 : 90)
        set global.self_test_found = global.self_test_found ^ "Heizung " ^ iterations ^ ": " ^ heat.heaters[iterations].current ^ " C statt " ^ global.self_test_heater_target[iterations] ^ " C nach " ^ var.elapsed ^ " s; "
        set var.off = true
      if var.off
        set global.self_test_heater_state[iterations] = 2
        M98 P"0:/sys/meltingplot/self-test/stop-heater.g" H{iterations}
    if global.self_test_heater_state[iterations] < 2
      set var.finished = false

  if var.finished && !var.aborted
    M98 P"0:/sys/meltingplot/self-test/report.g" T1

if var.aborted
  if global.self_test_step == 1
    while iterations < #global.fan_adjustable
      M106 P{global.fan_adjustable[iterations]} S0
  ; Only a heater still at this test's setpoint is this test's to switch off, and trigger3.g must
  ; not bring it back: a door that opened saved it as "active" (trigger4.g).
  while iterations <= #tools
    if global.self_test_heater_state[iterations] < 2 && heat.heaters[iterations].active == global.self_test_heater_target[iterations]
      if iterations == 0
        set global.saved_bed_heater_state = "off"
      else
        set global.saved_tool_heater_states[iterations - 1] = "off"
      M98 P"0:/sys/meltingplot/self-test/stop-heater.g" H{iterations}
  M118 P0 L2 S"Self-test: weekly check ended early - door, heater or job took over, it stays due"
  set global.self_test_retry[1] = state.upTime + 300
  set global.self_test_found = ""
  set global.self_test_run = -1
  set global.self_test_step = 0
  set global.self_test_manual = -1
