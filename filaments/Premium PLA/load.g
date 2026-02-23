; Load T0 with PLA
G10 P0 S215 R160                                    ; set temperatures
T0                                                  ; select tool
M116 P0                                             ; wait for temp
if state.currentTool == 0
  set global.deferred_filament_load_t0 = true