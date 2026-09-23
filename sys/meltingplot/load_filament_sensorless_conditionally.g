; load_filament_sensorless_conditionally.g - DEPRECATED forwarding file, delete with RRF 3.8
; (CLAUDE.md, "Deprecated forwarding files").
; 3.7 renamed it to sys/meltingplot/filament/on-config.g.
; The old path is still called by the config.g of filament profiles generated before 3.7:
; tpost0.g regenerates a profile on its next tool change, macro
; repair-filament-profile does it at once.
; Every call warns on the console and in the event log (M118 P0 L1, with the profile
; name where the call carries it), so the remaining callers can be found and fixed
; before 3.8.

M118 P0 L1 S"Warning: deprecated load_filament_sensorless_conditionally.g - run repair-filament-profile"
M98 P"0:/sys/meltingplot/filament/on-config.g"
