; MFM suppression expiry - expression trigger T7 (config.g, M581.1). The swing detection in
; daemon.g, filament/mfm-recovery.g and resume.g suppress MFM events until
; global.mfm_suppress_until; RRF fires this trigger when that time has passed while a job is
; loaded (R1, also while paused). The window ends only while the print is "processing": a
; window that expires during a pause must survive it, resume.g re-bases it to the actual
; restart of the print (2026-09-03). The expression holds no "processing" (a string literal
; is garbage on every main-loop pass, see config.g), so this macro checks it.
; Re-check before acting: a window extended between the fire and this macro must not be
; cut short - the trigger fires again when the new window ends.
if global.mfm_suppress_until > 0 && state.upTime >= global.mfm_suppress_until
  if state.status == "processing"
    set global.mfm_suppress_until = 0
    set global.mfm_ignore_events = false
    set global.mfm_prev_percentage = null
    if global.debug
      echo "MFM: suppression period ended, monitoring resumed"
  else
    ; Not processing (pausing, paused, resuming, cancelling): keep the window and move its
    ; end 10 s out. This fire used up the false -> true edge, and a window resume.g does
    ; not re-base (mfm_ignore_events cleared during the pause) would otherwise never end.
    ; One line, so print/finish.g's clear or resume.g's re-base on another channel cannot
    ; land between the read and the write: 0 stays 0, a later end is kept. While paused,
    ; state.status stays "paused" (it outranks "busy"), so the idle heater timer runs on.
    set global.mfm_suppress_until = global.mfm_suppress_until > 0 ? max(global.mfm_suppress_until, state.upTime + 10) : 0
