; tpre0.g
; called before tool 0 is selected
;

M98 P"0:/sys/meltingplot/ensure_safety"

if exists(global.filament_loading_error)
  set global.filament_loading_error = false
else
  global filament_loading_error = false
