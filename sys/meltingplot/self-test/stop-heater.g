; self-test/stop-heater.g
; Switches off a heater the weekly tier heated and gives a tool its setpoint back:
;   M98 P"0:/sys/meltingplot/self-test/stop-heater.g" H<heater> S<setpoint to give back>
; Heater 0 = bed, heater h = tool h-1. The tool heater needs an A0 on either side of its setpoint.
; After it: an M568 S on its own switches a remote heater on again. RemoteHeater::SwitchOff only sends
; the command, lastMode stays until the next CAN report, and Heater::SetTemperature switches on while
; lastMode reads on. On the lab machine the hotend stayed active at setpoint 0 after the first weekly
; run (rc.80, 2026-11-06), and with a filament's setpoint it would have heated to that. M568 works
; through R, S and A in that order (GCodes.cpp), so S and A0 in one command end on "off".
; Before it: an S at or above the heater's limit throws "Requested temperature out of range"
; (Tool.cpp), which skips the A in that command. Default mode caps every heater at 50 C, so a
; filament's setpoint does not fit once a door has opened during the test: the tool then ends at 0,
; the next load or job sets its temperature anyway. The limit is read first, but a door can open
; between the two lines.

if param.H == 0
  M140 P0 S-273.15
else
  var tool = param.H - 1
  M568 P{var.tool} A0
  if param.S < heat.heaters[param.H].max
    M568 P{var.tool} S{param.S} A0
  else
    M568 P{var.tool} S0 A0
    M118 P0 L2 S{"Self-test: setpoint of tool " ^ var.tool ^ " (" ^ param.S ^ " C) is above the limit now - set to 0"}
