; MFM suppression expiry - expression trigger T7 (config.g, M581.1). The swing detection in
; daemon.g, filament/mfm-recovery.g and resume.g suppress MFM events until
; global.mfm_suppress_until; RRF fires this trigger when that time has passed while the
; print is "processing". Only then: a window that expires during a pause must survive it,
; resume.g re-bases it to the actual restart of the print (2026-09-03).
; Re-check before acting: a window extended between the fire and this macro must not be
; cut short - the trigger fires again when the new window ends.
if global.mfm_suppress_until > 0 && state.status == "processing" && state.upTime >= global.mfm_suppress_until
  set global.mfm_suppress_until = 0
  set global.mfm_ignore_events = false
  set global.mfm_prev_percentage = null
  if global.debug
    echo "MFM: suppression period ended, monitoring resumed"
