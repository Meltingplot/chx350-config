; Machine specific variant configuration.
; Loaded at the end of sys/meltingplot/globals.g, i.e. before any hardware is configured
; in config.g. It lives in sys/overrides/, the directory a config update never
; overwrites (DWC config plugin and image alike), so local changes survive.
;
; Rules:
;   - assignments only: set global.<name> = <value>
;   - the variable must already be declared in sys/meltingplot/globals.g; declaring a new
;     one here would fail on the second boot ("global already exists")
;   - values only. Anything that needs G-code (M569 drive directions, M591 filament
;     monitor, M307 heater models, ...) belongs in machine-override, not here.
;   - a feature is switched on or off, never reconfigured. Pin assignment is identical
;     on every machine (CE documentation) and lives in config.g.
;
; Any global declared in globals can be overridden - the entries below are the switches
; for optional hardware, uncomment the ones this machine actually has, and machine values
; with their default.

; Auxiliary part cooling fan on fan 2 (out2). OrcaSlicer addresses it as M106 P2 (enable
; "Auxiliary part cooling fan" in the printer profile and set the speed per filament).
;set global.has_aux_fan = true

; Exhaust / chamber fan on fan 3 (out1). OrcaSlicer addresses it as M106 P3 (air filtration).
;set global.has_exhaust_fan = true

; Bed temperature the preheat flow (macro startup/preheat) heats to when none of the
; loaded filament profiles sets one in its temps.g (set global.filament_temp_bed = ...).
;set global.preheat_bed_temp = 60
