; filament_unload.g
; Shared body for filaments/<name>/unload.g (invoked by M702). The machine-generated
; unload.g contains a single call:
;   M98 P"0:/sys/meltingplot/filament_unload.g" F"<profile name>"
; Temperatures come from filaments/<name>/temps.g (sets global.filament_temp_*);
; filament_temp_unload = 0 means "unload at the active temperature". Legacy form
; S<active_temp> is still accepted (standby fixed at 160). NOTE: an R parameter on
; M98 is NOT passed to the macro (M98 consumes R as its pause-allowed flag).

; Daemon-initiated forced unload (broken-profile watchdog / failed-load cleanup):
; skip the physical unload entirely so the daemon's M702 cannot block - M702 then
; only clears the filament assignment. MUST stay the first statement.
if global.filament_forced_unload
  M99

if global.debug
  echo "filament_unload.g"

var active = 0
var standby = 160
if exists(param.F)
  set global.filament_temp_active = 0
  set global.filament_temp_standby = 160
  set global.filament_temp_unload = 0
  if fileexists("0:/filaments/" ^ param.F ^ "/temps.g")
    M98 P{"0:/filaments/" ^ param.F ^ "/temps.g"}
  if global.filament_temp_active <= 0 && global.filament_temp_unload <= 0
    abort "filament_unload.g: filaments/" ^ param.F ^ "/temps.g missing or invalid - run macro repair-filament-profile"
  set var.active = global.filament_temp_unload > 0 ? global.filament_temp_unload : global.filament_temp_active
  set var.standby = global.filament_temp_standby
elif exists(param.S)
  set var.active = param.S
else
  abort "filament_unload.g: missing F (profile name) or S (active temperature) parameter"

if state.currentTool == -1
  T0 ; console M702 without a tool selected - use the default tool
if state.currentTool == -1
  abort "filament_unload.g: no tool selected"

G10 P{state.currentTool} S{var.active} R{var.standby} ; set temperatures
if heat.heaters[tools[state.currentTool].heaters[0]].current < heat.heaters[tools[state.currentTool].heaters[0]].active
  M116 P{state.currentTool} ; wait only when heating up

M98 P"0:/sys/meltingplot/unload_filament"
