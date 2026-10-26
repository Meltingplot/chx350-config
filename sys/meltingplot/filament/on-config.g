; filament/on-config.g
; Checks the per-tool deferred filament load flag (armed by filament/on-load.g from
; the profile's load.g) and runs filament/load-procedure.g if needed. Called from
; the machine-generated filaments/<name>/config.g - the only post-M701 hook where
; move.extruders[n].filament is valid.
; The physical-load marker is set BEFORE the flag is cleared so the daemon.g
; watchdog can never observe (flag=false and marker unset) during a correct load.

; Exhaust run-on of this material (trigger9.g): config-override.g, which config.g ran just
; before, may have set filament_exhaust_run_on. Take it over for the tool and reset the
; hand-over, so a profile without the line never inherits the previous profile's value.
; First, so the tool has it already while the load below runs (a door opened during the load).
if state.currentTool >= 0
  set global.fan_exhaust_run_on[state.currentTool] = global.filament_exhaust_run_on
set global.filament_exhaust_run_on = 0

if state.currentTool >= 0 && global.filament_load_pending[state.currentTool]
  set global.filament_load_dispatched = move.extruders[tools[state.currentTool].extruders[0]].filament
  set global.filament_load_pending[state.currentTool] = false
  M98 P"0:/sys/meltingplot/filament/load-procedure.g"

M400 ; sbc specific
