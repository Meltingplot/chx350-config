; Load T0 with PETG
G10 P0 S255 R180                                    ; set temperatures for TPC
T0                                                  ; select tool
M116 P0                                             ; wait for temp
if state.currentTool == 0
  set global.deferred_filament_load_t0 = true