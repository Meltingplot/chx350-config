; filament/on-config.g
; Checks the per-tool deferred filament load flag (armed by filament/on-load.g from
; the profile's load.g) and runs filament/load-procedure.g if needed. Called from
; the machine-generated filaments/<name>/config.g - the only post-M701 hook where
; move.extruders[n].filament is valid.
; The physical-load marker is set BEFORE the flag is cleared so the daemon.g
; watchdog can never observe (flag=false and marker unset) during a correct load.

if state.currentTool >= 0 && global.filament_load_pending[state.currentTool]
  set global.filament_load_dispatched = move.extruders[tools[state.currentTool].extruders[0]].filament
  set global.filament_load_pending[state.currentTool] = false
  M98 P"0:/sys/meltingplot/filament/load-procedure.g"

M400 ; sbc specific
