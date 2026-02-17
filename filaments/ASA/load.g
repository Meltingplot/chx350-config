; Load T0 with ASA
G10 P0 S255 R180                                ; set temperatures for PLA+
T0                                              ; select tool
M116 P0                                         ; wait for temp
M98 P"0:/sys/meltingplot/load_filament_sensorless"   ; load filament