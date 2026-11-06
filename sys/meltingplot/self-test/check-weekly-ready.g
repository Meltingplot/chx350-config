; self-test/check-weekly-ready.g
; Can the weekly tier run now? Hands the answer back in global.self_test_weekly_ready: both doors
; closed, every heater off, the machine cold, the operator's fans at 0, every tool's setpoint within
; its limit. Called by start.g and the flow maintenance/self-test, reads and set only.
; The setpoint limit: a tool keeps its filament's temperature while its heater is off, and under
; default mode's 50 C cap the test could not give it back (self-test/stop-heater.g).

set global.self_test_weekly_ready = sensors.gpIn[2].value == 1 && sensors.gpIn[3].value == 1
while iterations <= #tools
  if heat.heaters[iterations].state != "off" || heat.heaters[iterations].current > ((iterations == 0) ? 40 : 35)
    set global.self_test_weekly_ready = false
  elif iterations > 0
    if tools[iterations - 1].active[0] >= heat.heaters[iterations].max
      set global.self_test_weekly_ready = false
while iterations < #global.fan_adjustable
  if fans[global.fan_adjustable[iterations]].requestedValue != 0
    set global.self_test_weekly_ready = false
