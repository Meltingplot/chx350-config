; filament_unload.g
; Shared body for filaments/<name>/unload.g (invoked by M702). The only line a
; profile's unload.g needs:
;   M98 P"0:/sys/meltingplot/filament_unload.g" S<active_temp> R<standby_temp>
; S is required; R defaults to 160.

; Daemon-initiated forced unload (broken-profile watchdog / failed-load cleanup):
; skip the physical unload entirely so the daemon's M702 cannot block - M702 then
; only clears the filament assignment. MUST stay the first statement.
if global.filament_forced_unload
  M99

if global.debug
  echo "filament_unload.g"

if !exists(param.S)
  abort "filament_unload.g: missing S (active temperature) parameter"

if state.currentTool == -1
  T0 ; console M702 without a tool selected - use the default tool
if state.currentTool == -1
  abort "filament_unload.g: no tool selected"

G10 P{state.currentTool} S{param.S} R{exists(param.R) ? param.R : 160} ; set temperatures
if heat.heaters[tools[state.currentTool].heaters[0]].current < heat.heaters[tools[state.currentTool].heaters[0]].active
  M116 P{state.currentTool} ; wait only when heating up

M98 P"0:/sys/meltingplot/unload_filament"
