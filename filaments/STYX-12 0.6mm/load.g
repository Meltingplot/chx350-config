G10 P0 S255 R180                                    ; set temperatures for PLA+
T0                                                  ; select tool
M116                                                ; wait for temp
if state.currentTool == 0
  set global.deferred_filament_load_t0 = true