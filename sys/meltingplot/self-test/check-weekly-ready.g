; self-test/check-weekly-ready.g
; Can the weekly tier run now? Hands the answer back in global.self_test_weekly_ready: both doors
; closed, every heater off and far enough below its limit for the test's target, every tool's setpoint
; within its limit, the operator's fans at 0. Called by self-test/weekly-before-job.g and the flow
; maintenance/self-test, reads and set only.
;   M98 P"0:/sys/meltingplot/self-test/check-weekly-ready.g" [F1]
; F1: the caller runs the operator's fans itself to cool the machine, so they are not checked.
; The temperature is relative: check-weekly.g heats the bed to ceil(now) + 4 C and the hotend to
; ceil(now) + 10 C, at least 45 C, and both targets stay 5 C under the heater's limit (M143), which the
; object model gives for the mode the machine is in. Default mode (50 C, operating-mode/default.g)
; allows the bed at 41 C and the hotend at 35 C at most, so a cold machine runs the test before anyone
; checked the doors. A warm one needs automatic mode (120 C / 300 C): in a production hall at 40-45 C
; in summer the machine never cools below 41 C (2026-11-12).
; The setpoint limit: a tool keeps its filament's temperature while its heater is off, and under
; default mode's 50 C cap the test could not give it back (self-test/stop-heater.g).

set global.self_test_weekly_ready = sensors.gpIn[2].value == 1 && sensors.gpIn[3].value == 1
while iterations <= #tools
  if heat.heaters[iterations].state != "off" || heat.heaters[iterations].current > heat.heaters[iterations].max - ((iterations == 0) ? 9 : 15)
    set global.self_test_weekly_ready = false
  elif iterations > 0
    if tools[iterations - 1].active[0] >= heat.heaters[iterations].max
      set global.self_test_weekly_ready = false
if !exists(param.F)
  while iterations < #global.fan_adjustable
    if fans[global.fan_adjustable[iterations]].requestedValue != 0
      set global.self_test_weekly_ready = false
