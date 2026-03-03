G10 P0 S220 R160                            ; set temperatures for PETG
T0                                          ; Select T0
if heat.heaters[tools[0].heaters[0]].current < heat.heaters[tools[0].heaters[0]].active
  M116 P0                 ; wait for T0 only if we need to heat up
M98 P"0:/sys/meltingplot/unload_filament"   ; unload filament