; load_filament_sensorless_conditionally.g
; Checks the per-tool deferred filament load flag (armed by filament_load.g from
; the profile's load.g) and runs load_filament_sensorless if needed. Called from
; the machine-generated filaments/<name>/config.g - the only post-M701 hook where
; move.extruders[n].filament is valid.
; The physical-load marker is set BEFORE the flag is cleared so the daemon.g
; watchdog can never observe (flag=false and marker unset) during a correct load.

if state.currentTool >= 0 && global.deferred_filament_load[state.currentTool]
  set global.filament_physical_load_name = move.extruders[tools[state.currentTool].extruders[0]].filament
  set global.deferred_filament_load[state.currentTool] = false
  M98 P"0:/sys/meltingplot/load_filament_sensorless"

M400 ; sbc specific
