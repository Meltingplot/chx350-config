; Machine tick - expression trigger T8 (config.g, M581.1), every 10 s:
; - sample the coolant loop's fans (fan/check-coolant.g - OM reads, set and M118). This tick is
;   the single producer of the stall state: one writer, on the Trigger channel
; - switch off the operator's fans after fan_idle_timeout without a change while idle or
;   paused (fan/check-idle.g - OM reads, set, M118 and M106)
; - every 60 s while the print is "processing": book the print's extrusion onto the spool
;   (spool/track.g - OM reads and set only, no file write; print/finish.g writes at the job
;   end) and take the MFM flow-bias sample (filament/mfm-flow-bias.g - OM reads, set and a
;   non-blocking M118). A booking skipped in a pause comes at the first tick after the resume.
; The tick re-arms first: the trigger fires only on false -> true, so tick_time has to move on
; whatever this macro does after.
; Outside a job the tick runs only on firmware whose trigger macros do not make the machine
; "busy" (Meltingplot RRF 3.7.0+1.mp.4 and later, config.g checks it): busy restarts daemon.g's
; idle heater timer, so on older firmware a tick in idle would keep the heater cutoff from ever
; firing - there config.g gates the tick on the job, as T8 was before, and the coolant sample
; and the idle fan shut-off run only while a job is loaded. While paused, state.status stays
; "paused" either way (it outranks "busy").
; Nothing in here may block: this macro holds the Trigger channel, and trigger4.g (door
; opened) waits behind it.
set global.tick_time = state.upTime
M98 P"0:/sys/meltingplot/fan/check-coolant.g"
M98 P"0:/sys/meltingplot/fan/check-idle.g"
if state.status == "processing" && state.upTime - global.spool_track_time >= 60
  set global.spool_track_time = state.upTime
  M98 P"0:/sys/meltingplot/spool/track.g"
  M98 P"0:/sys/meltingplot/filament/mfm-flow-bias.g"
