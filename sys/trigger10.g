; Exhaust run-on end - expression trigger T10 (config.g, M581.1, only with has_exhaust_fan).
; RRF fires it when global.fan_exhaust_until has passed: trigger9.g sets it when a door opens
; and moves it to now when both doors close during a job, start.g at the job start. During a
; job the exhaust goes back to the value the job had set (fan_exhaust_job_value), outside a
; job it goes off. The only writer of 0.
; Re-check before acting: trigger9.g may have extended the run-on between the fire and this
; macro - the trigger fires again when the new run-on ends.
if global.fan_exhaust_until > 0 && state.upTime >= global.fan_exhaust_until
  M106 P3 S{job.file.fileName != null ? global.fan_exhaust_job_value : 0}
  set global.fan_exhaust_until = 0
