; filament_load.g
; Shared body for filaments/<name>/load.g (invoked by M701). The only line a
; profile's load.g needs:
;   M98 P"0:/sys/meltingplot/filament_load.g" S<active_temp> R<standby_temp>
; S is required; R defaults to 160.
; Sets temperatures, selects the default tool if none is active, waits for
; heat-up and arms the deferred physical load. The load itself runs later via
; load_filament_sensorless_conditionally.g (from the machine-generated config.g)
; because move.extruders[n].filament is only valid AFTER load.g returns.

if global.debug
  echo "filament_load.g"

if !exists(param.S)
  abort "filament_load.g: missing S (active temperature) parameter"

if state.currentTool == -1
  T0 ; console M701 without a tool selected - use the default tool
if state.currentTool == -1
  abort "filament_load.g: no tool selected"

G10 P{state.currentTool} S{param.S} R{exists(param.R) ? param.R : 160} ; set temperatures
if heat.heaters[tools[state.currentTool].heaters[0]].current < heat.heaters[tools[state.currentTool].heaters[0]].active
  M116 P{state.currentTool} ; wait only when heating up (skip pointless cool-down wait)

set global.deferred_filament_load[state.currentTool] = true
