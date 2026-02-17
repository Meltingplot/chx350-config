G10 P0 S255 R180                            ; set temperatures for TPC
T0                                          ; Select T0
M116 P0                                     ; wait for temp
M98 P"0:/sys/meltingplot/unload_filament"   ; unload filament