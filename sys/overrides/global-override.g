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

; Exhaust clean cycle after a boot (s, only with the exhaust fan): config.g runs the exhaust
; this long right after the start. 0 = none.
;set global.fan_exhaust_boot_run_on = 600

; Part cooling fans switched on by hand (CHX 350 UI) go off when their values have not
; changed for this long (s) while the machine is idle or paused. Capped at 7200 s.
;set global.fan_idle_timeout = 1800

; Bed temperature the preheat flow (macro startup/preheat) heats to when none of the
; loaded filament profiles sets one in its temps.g (set global.filament_temp_bed = ...).
;set global.preheat_bed_temp = 60

; Net-feed watchdog (daemon.g): pauses the print when the filament monitor's wheel moved less
; than this share of the commanded extrusion over 3 mm. 0 switches it off; the filament
; monitor's own check (M591 in machine-override) stays active either way.
;set global.mfm_feed_min_ratio = 0.4

; Z of the bed at its lower stop, measured from the nozzle touching the bed (CAD nominal
; 950.3 mm). Only for a machine whose travel exceeds it by more than ~2 mm: homez.g's touch
; probe reaches no deeper than 2.1 mm below this frame's Z0 after aligning.
;set global.z_lower_stop = 950.3
