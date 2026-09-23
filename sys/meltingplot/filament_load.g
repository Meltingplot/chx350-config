; filament_load.g - DEPRECATED forwarding file, delete with RRF 3.8
; (CLAUDE.md, "Deprecated forwarding files").
; 3.7 renamed it to sys/meltingplot/filament/on-load.g.
; The old path is still called by the load.g of filament profiles generated before 3.7:
; tpost0.g regenerates a profile on its next tool change, macro
; repair-filament-profile does it at once.
; Every call warns on the console and in the event log (M118 P0 L1, with the profile
; name where the call carries it), so the remaining callers can be found and fixed
; before 3.8.

if exists(param.F)
  M118 P0 L1 S{"Warning: deprecated filament_load.g - run repair-filament-profile for '" ^ param.F ^ "'"}
  M98 P"0:/sys/meltingplot/filament/on-load.g" F{param.F}
elif exists(param.S)
  M118 P0 L1 S"Warning: deprecated filament_load.g (S<temperature> form) - run repair-filament-profile"
  M98 P"0:/sys/meltingplot/filament/on-load.g" S{param.S}
else
  M118 P0 L1 S"Warning: deprecated filament_load.g - run repair-filament-profile"
  M98 P"0:/sys/meltingplot/filament/on-load.g"
