; Load T0 with PolySmooth
G10 P0 S198 R160                                    ; set temperatures for PolySmooth
T0                                                  ; select tool
M116 P0                                             ; wait for temp
if state.currentTool == 0
  set global.deferred_filament_load_t0 = true