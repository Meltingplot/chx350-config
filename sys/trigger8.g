; Spool booking while printing - expression trigger T8 (config.g, M581.1). RRF fires this
; trigger every 60 s while the print is "processing": book the print's extrusion onto
; the spool (spool/track.g - OM reads and set only, no file write; print/finish.g writes
; at the job end). Never while idle: a running trigger macro makes state.status "busy",
; which restarts daemon.g's idle heater timer. Outside a print daemon.g books at every
; extruder stop.
set global.spool_track_time = state.upTime
M98 P"0:/sys/meltingplot/spool/track.g"
