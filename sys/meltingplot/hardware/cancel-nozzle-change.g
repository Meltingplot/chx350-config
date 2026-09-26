; hardware/cancel-nozzle-change.g
; Leaves a safe state when the guided nozzle change of macro maintenance/set-nozzle-diameter
; ends early - the operator cancelled a prompt or let it time out, or the tool selection,
; the unload, the homing or the return to automatic mode failed:
; - The nozzle heater off, and kept off. A door opened during the change made trigger4.g
;   save the heater as "active", and trigger3.g would switch it on again when the doors
;   close - heating a hotend that may have no nozzle in it, with nobody at the machine.
;   "off" is the value trigger3.g leaves behind itself and the restrictive one (globals,
;   saved_*_heater_state*). It is written before the M568: a restore running in between
;   either finds it or is switched off by the M568.
; - A paused job gets the tool state pause.g left it in: no tool selected, heater on
;   standby - resume.g re-selects with T R1 and waits for the heater before it moves.
;   M98 P"0:/sys/meltingplot/hardware/cancel-nozzle-change.g" T0 S"<reason>"
; S is the reason in the error line, default "cancelled or timed out". The closing
; "Error:" line marks the flow as not completed in the CHX 350 UI.

if global.debug
  echo "hardware/cancel-nozzle-change.g"

var tool = exists(param.T) ? ((param.T == 1) ? 1 : 0) : min(max(state.currentTool, 0), 1)

if state.messageBox != null
  M292                                              ; a progress box of the flow may still be open
set global.saved_tool_heater_states[var.tool] = "off"
M568 P{var.tool} A0                                 ; nozzle heater off
if state.status == "paused"
  T-1 P0
echo "Error: nozzle change on T" ^ var.tool ^ " " ^ (exists(param.S) ? param.S : "cancelled or timed out") ^ " - check that a nozzle is fitted and tight before heating"
