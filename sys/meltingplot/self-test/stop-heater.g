; self-test/stop-heater.g
; Switches off a heater the weekly tier heated and gives a tool its setpoint back:
;   M98 P"0:/sys/meltingplot/self-test/stop-heater.g" H<heater>
; Heater 0 = bed, heater h = tool h-1. A0 on a line of its own and first: M568 works through R, S
; and A in that order (GCodes.cpp), and an S at or above the heater's limit throws "Requested
; temperature out of range" (Tool.cpp), which skips the A and leaves the heater on. Default mode
; caps every heater at 50 C, so a filament's setpoint does not fit once a door has opened during
; the test: the tool then ends at 0, the next load or job sets its temperature anyway. Without A,
; M568 only stores the setpoint.

if param.H == 0
  M140 P0 S-273.15
else
  var tool = param.H - 1
  M568 P{var.tool} A0
  if global.self_test_saved_active[param.H] < heat.heaters[param.H].max
    M568 P{var.tool} S{global.self_test_saved_active[param.H]}
  else
    M568 P{var.tool} S0
    M118 P0 L2 S{"Self-test: setpoint of tool " ^ var.tool ^ " (" ^ global.self_test_saved_active[param.H] ^ " C) is above the limit now - set to 0"}
