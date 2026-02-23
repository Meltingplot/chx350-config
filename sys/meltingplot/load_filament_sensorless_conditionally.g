; load_filament_sensorless_conditionally.g
; Checks deferred filament load flag and runs load_filament_sensorless if needed

if global.deferred_filament_load_t0
  set global.deferred_filament_load_t0 = false
  M98 P"0:/sys/meltingplot/load_filament_sensorless"
