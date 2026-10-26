; fan/check-coolant.g
; Coolant loop watchdog - one sample of the water loop's fans (config.g):
;   fans 4, 5  radiators, thermostatic on the hotend: 100 % above 40 C, off below
;   fan 6      water pump: runs at every PWM value, also at 0 % (799 rpm at requestedValue 0,
;              read 2026-10-26), so only the tacho tells - it should always run
; A fan that stands although it should run (rpm 0: no tacho pulse for 3 s, RRF
; LocalFan::GetRPM) is suspected; still standing at a sample 5 s or more later it is stalled
; and goes into global.fan_stalled, which the CHX 350 UI shows as a banner and start.g
; refuses a new job on. A running print goes on - the machine also cools passively. One
; sample with the fan running takes it out again. A fan that is not driven (radiators below
; 40 C) tells nothing: a suspicion is dropped, a stall stays until the fan runs again.
; State per fan in global.fan_stall_state (globals.g).
; Called by trigger8.g every 60 s while printing, by daemon.g every 10 s otherwise and by
; start.g. OM reads, set and M118 only - nothing in here may block.
;   M98 P"0:/sys/meltingplot/fan/check-coolant.g" [S1]
; S1 hands the number of suspected fans back in global.result, so start.g knows to sample
; once more. Only with S1: daemon.g and trigger8.g run on channels of their own, and a write
; from there would overwrite global.result while another channel is between a call and the
; line that reads it.

var changed = false
var suspected = 0
while iterations < 3
  var n = iterations + 4
  if fans[var.n].rpm > 0
    if global.fan_stall_state[var.n] != 0
      if global.fan_stall_state[var.n] == -1
        M118 P0 S{"Fan " ^ var.n ^ " (" ^ fans[var.n].name ^ ") runs again"}
        set var.changed = true
      set global.fan_stall_state[var.n] = 0
  elif var.n == 6 || fans[var.n].actualValue > 0
    if global.fan_stall_state[var.n] == 0
      set global.fan_stall_state[var.n] = state.upTime
    elif global.fan_stall_state[var.n] > 0 && state.upTime - global.fan_stall_state[var.n] >= 5
      set global.fan_stall_state[var.n] = -1
      set var.changed = true
      M118 P0 S{"Warning: fan " ^ var.n ^ " (" ^ fans[var.n].name ^ ") stands still although it should run - no new print job until it runs again"}
    if global.fan_stall_state[var.n] > 0
      set var.suspected = var.suspected + 1
  elif global.fan_stall_state[var.n] > 0
    set global.fan_stall_state[var.n] = 0

if var.changed
  var stalled = vector(0, 0)
  while iterations < #global.fan_stall_state
    if global.fan_stall_state[iterations] == -1
      set var.stalled = var.stalled ^ vector(1, iterations)
  set global.fan_stalled = var.stalled

if exists(param.S)
  set global.result = var.suspected
