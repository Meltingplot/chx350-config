; MFM speed restore - expression trigger T6 (config.g, M581.1). filament-error.g lowers the
; speed (M220) on every P=4/P=5 error; RRF fires this trigger 30 s after the last backoff
; step while printing, or at once when no print is running. The restore is unconditional
; and time-based on purpose: reduced speed itself depresses the MFM reading, so waiting
; for the reading to recover deadlocks (CLAUDE.md, MFM). daemon.g keeps the fast-track
; restore on a good reading.
; Re-check before acting: filament-error.g may have stepped down again between the fire
; and this macro (fresh mfm_backoff_time) - that window gets its own 30 s, and the trigger
; fires again once the condition turns true.
if global.mfm_backoff_level < 3 && (state.status != "processing" || job.file.fileName == null || state.upTime - global.mfm_backoff_time >= 30)
  M220 S100
  set global.mfm_backoff_level = 3
  set global.mfm_backoff_time = state.upTime
  if global.debug
    echo "MFM: speed restored to 100%"
