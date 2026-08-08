; filament_unload.g
; Shared body for filaments/<name>/unload.g (invoked by M702). The machine-generated
; unload.g contains a single call:
;   M98 P"0:/sys/meltingplot/filament_unload.g" F"<profile name>"
; Temperatures come from filaments/<name>/temps.g (sets global.filament_temp_*);
; filament_temp_unload = 0 means "unload at the active temperature". Legacy form
; S<active_temp> is still accepted (standby fixed at 160). NOTE: an R parameter on
; M98 is NOT passed to the macro (M98 consumes R as its pause-allowed flag).
; NEVER use abort in the load/unload path: it terminates the current print file too,
; so a broken filament profile would kill a running job. Warn (M118 P0 reaches every
; channel - echo only answers the caller) and return with M99. The physical unload is
; then skipped while M702 still clears the assignment - the name -> "" transition
; without filament_physical_unload_done is what the daemon watchdog reports.

; Daemon-initiated forced unload (broken-profile watchdog / failed-load cleanup):
; skip the physical unload entirely so the daemon's M702 cannot block - M702 then
; only clears the filament assignment. Self-clear the one-shot flag right here (M702
; always runs this script), so it can never get stuck set. MUST stay first.
if global.filament_forced_unload
  set global.filament_forced_unload = false
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
    M118 P0 S{"Error: filament_unload.g: filaments/" ^ param.F ^ "/temps.g missing or invalid - run macro repair-filament-profile"}
    M99
  set var.active = global.filament_temp_unload > 0 ? global.filament_temp_unload : global.filament_temp_active
  set var.standby = global.filament_temp_standby
elif exists(param.S)
  set var.active = param.S
else
  M118 P0 S"Error: filament_unload.g: missing F (profile name) or S (active temperature) parameter"
  M99

if state.currentTool == -1
  T0 ; console M702 without a tool selected - use the default tool
if state.currentTool == -1
  M118 P0 S"Error: filament_unload.g: no tool selected"
  M99

M568 P{state.currentTool} S{var.active} R{var.standby} A2 ; set temperatures
if heat.heaters[tools[state.currentTool].heaters[0]].current < heat.heaters[tools[state.currentTool].heaters[0]].active
  M116 P{state.currentTool} ; wait only when heating up

M98 P"0:/sys/meltingplot/unload_filament"
