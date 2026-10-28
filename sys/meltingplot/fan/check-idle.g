; fan/check-idle.g
; Idle shut-off of the operator's fans (fan_adjustable, set by hand in the CHX 350 UI): they go
; off when their values have not changed for fan_idle_timeout while the machine is idle or
; paused - a forgotten fan. Every change restarts the time, so does any other state: a print
; or a macro ("busy") owns the fans meanwhile, and a print switches them off at its end.
; State in global.fan_idle_sum / fan_idle_off_at (globals.g). Called by trigger8.g (machine
; tick, every 10 s). OM reads, set, M118 and M106 only - nothing in here may block.

if state.status == "idle" || state.status == "paused"
  var sum = 0
  while iterations < #global.fan_adjustable
    set var.sum = var.sum + fans[global.fan_adjustable[iterations]].requestedValue
  if var.sum == 0 || var.sum != global.fan_idle_sum
    set global.fan_idle_off_at = state.upTime + min(global.fan_idle_timeout, 7200)
  elif state.upTime >= global.fan_idle_off_at
    M118 P0 S{"Idle cutoff: operator fans off after " ^ floor(min(global.fan_idle_timeout, 7200) / 60) ^ " min without a change"}
    while iterations < #global.fan_adjustable
      M106 P{global.fan_adjustable[iterations]} S0
  set global.fan_idle_sum = var.sum
else
  set global.fan_idle_sum = -1                            ; restarts the time at the next idle tick
