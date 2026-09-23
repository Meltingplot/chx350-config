; load_nozzle_config.g - DEPRECATED forwarding file, delete with RRF 3.8
; (CLAUDE.md, "Deprecated forwarding files").
; 3.7 renamed it to sys/meltingplot/filament-profile/apply-nozzle-file.g.
; The old path is still called by the config.g of filament profiles generated before 3.7:
; tpost0.g regenerates a profile on its next tool change, macro
; repair-filament-profile does it at once.
; Every call warns on the console and in the event log (M118 P0 L1, with the profile
; name where the call carries it), so the remaining callers can be found and fixed
; before 3.8.

if exists(param.S)
  M118 P0 L1 S{"Warning: deprecated load_nozzle_config.g - run repair-filament-profile for '" ^ param.S ^ "'"}
  M98 P"0:/sys/meltingplot/filament-profile/apply-nozzle-file.g" S{param.S}
else
  M118 P0 L1 S"Warning: deprecated load_nozzle_config.g - run repair-filament-profile"
  M98 P"0:/sys/meltingplot/filament-profile/apply-nozzle-file.g"
