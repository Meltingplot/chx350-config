; Print tick - expression trigger T8 (config.g, M581.1). RRF fires this trigger every 60 s
; while a job is loaded (also while paused); the work runs only while the print is
; "processing":
; - book the print's extrusion onto the spool (spool/track.g - OM reads and set only, no
;   file write; print/finish.g writes at the job end)
; - take the MFM flow-bias sample (filament/mfm-flow-bias.g - OM reads, set and a
;   non-blocking M118)
; The expression holds no "processing" (a string literal is garbage on every main-loop
; pass, see config.g), so this macro checks it - after re-arming the tick: the trigger fires
; only on false -> true, and a tick skipped in a pause that left spool_track_time behind
; would keep the expression true, so the tick would not come back after the resume.
; Nothing in here may block: this macro holds the Trigger channel, and trigger4.g (door
; opened) waits behind it. Never while idle: a running trigger macro makes state.status
; "busy", which restarts daemon.g's idle heater timer - the job gate keeps T8 off while
; idle, and while paused state.status stays "paused". Outside a print daemon.g books at
; every extruder stop.
set global.spool_track_time = state.upTime
if state.status != "processing"
  M99
M98 P"0:/sys/meltingplot/spool/track.g"
M98 P"0:/sys/meltingplot/filament/mfm-flow-bias.g"
