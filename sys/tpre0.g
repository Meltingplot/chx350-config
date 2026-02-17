; tpre0.g
; called before tool 0 is selected
;

if exists(global.filament_loading_error)
  set global.filament_loading_error = false
else
  global filament_loading_error = false
