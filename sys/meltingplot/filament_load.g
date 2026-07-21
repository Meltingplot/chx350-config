; filament_load.g
; Shared body for filaments/<name>/load.g (invoked by M701). The machine-generated
; load.g contains a single call:
;   M98 P"0:/sys/meltingplot/filament_load.g" F"<profile name>"
; Temperatures come from filaments/<name>/temps.g (sets global.filament_temp_*).
; Legacy form S<active_temp> is still accepted (standby fixed at 160). NOTE: an R
; parameter on M98 is NOT passed to the macro (M98 consumes R as its pause-allowed
; flag), so a standby temperature can never be a macro parameter here.
; Sets temperatures, selects the default tool if none is active, waits for
; heat-up and arms the deferred physical load. The load itself runs later via
; load_filament_sensorless_conditionally.g (from the machine-generated config.g)
; because move.extruders[n].filament is only valid AFTER load.g returns.

if global.debug
  echo "filament_load.g"

var active = 0
var standby = 160
if exists(param.F)
  set global.filament_temp_active = 0
  set global.filament_temp_standby = 160
  set global.filament_temp_unload = 0
  if fileexists("0:/filaments/" ^ param.F ^ "/temps.g")
    M98 P{"0:/filaments/" ^ param.F ^ "/temps.g"}
  if global.filament_temp_active <= 0
    abort "filament_load.g: filaments/" ^ param.F ^ "/temps.g missing or invalid - run macro repair-filament-profile"
  set var.active = global.filament_temp_active
  set var.standby = global.filament_temp_standby
elif exists(param.S)
  set var.active = param.S
else
  abort "filament_load.g: missing F (profile name) or S (active temperature) parameter"

if state.currentTool == -1
  T0 ; console M701 without a tool selected - use the default tool
if state.currentTool == -1
  abort "filament_load.g: no tool selected"

M568 P{state.currentTool} S{var.active} R{var.standby} A2 ; set temperatures
if heat.heaters[tools[state.currentTool].heaters[0]].current < heat.heaters[tools[state.currentTool].heaters[0]].active
  M116 P{state.currentTool} ; wait only when heating up (skip pointless cool-down wait)

set global.deferred_filament_load[state.currentTool] = true
