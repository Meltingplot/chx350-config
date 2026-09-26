; filament/end-mfm-calibration.g
; Ends a calibration measured with the filament monitor (calibration/e-steps,
; calibration/nle) - at the regular end and at every exit after the measurement started.
; The measurement samples every move (M591 S2 E1) and has filament errors ignored
; (global.mfm_ignore_events); an exit that only returned left the monitor in calibration
; mode and filament errors ignored until the next print end cleared the flag
; (print/finish.g).
; - closes a progress box of the flow: the next prompt would replace it, an exit leaves it open
; - the filament monitor back to print moves and the sample distance E it had, then
;   sys/overrides/machine-override, which configures the monitor
; - filament errors on again
; The caller selects its previous tool again itself (T-1, T<n>), so that tpost0.g applies
; the profile's pressure advance, NLE and e-steps again, which the measurement reset. That T
; must not move in here: from the filament load of flow maintenance/change-filament it
; would push tpost0.g's M703 chain (config.g, filament-profile/apply-nozzle-file.g,
; filament-profile/find-calibration-file.g, lib/format-number.g) one level past the 10
; nested macros RRF allows.
;   M98 P"0:/sys/meltingplot/filament/end-mfm-calibration.g" D<extruder> E<sample distance>

if global.debug
  echo "filament/end-mfm-calibration.g"

if state.messageBox != null
  M292                                              ; a progress box of the flow may still be open
M591 D{param.D} A1 S1 E{param.E}                    ; filament monitor: print moves only, previous sample distance
M98 P"0:/sys/overrides/machine-override"            ; machine specific overrides, the filament monitor among them
set global.mfm_ignore_events = false                ; filament errors on again
