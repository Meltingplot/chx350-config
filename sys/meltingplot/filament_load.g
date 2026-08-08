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
; NEVER use abort in the load/unload path: it terminates the current print file too,
; so a broken filament profile would kill a running job. Warn (M118 P0 reaches every
; channel - echo only answers the caller) and return with M99. Returning before the
; deferred flag is armed is the safe outcome: no physical load is dispatched, which is
; exactly the signature the broken-profile watchdog in daemon.g detects and cleans up.

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
    M118 P0 S{"Error: filament_load.g: filaments/" ^ param.F ^ "/temps.g missing or invalid - run macro repair-filament-profile"}
    M99
  set var.active = global.filament_temp_active
  set var.standby = global.filament_temp_standby
elif exists(param.S)
  set var.active = param.S
else
  M118 P0 S"Error: filament_load.g: missing F (profile name) or S (active temperature) parameter"
  M99

if state.currentTool == -1
  T0 ; console M701 without a tool selected - use the default tool
if state.currentTool == -1
  M118 P0 S"Error: filament_load.g: no tool selected"
  M99

M568 P{state.currentTool} S{var.active} R{var.standby} A2 ; set temperatures
if heat.heaters[tools[state.currentTool].heaters[0]].current < heat.heaters[tools[state.currentTool].heaters[0]].active
  M116 P{state.currentTool} ; wait only when heating up (skip pointless cool-down wait)

set global.deferred_filament_load[state.currentTool] = true
