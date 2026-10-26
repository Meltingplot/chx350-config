; Exhaust run-on end - expression trigger T10 (config.g, M581.1, only with has_exhaust_fan).
; RRF fires it when global.fan_exhaust_until has passed. Set by config.g (clean cycle after the
; boot), print/finish.g (job end) and trigger9.g (door opened); moved to now by trigger9.g when
; both doors close on a run-on a door started during a job, and by start.g at the job start.
; A run-on a door started during a job gives the exhaust back to the value the job had set
; (fan_exhaust_job_value), every other one switches it off. The only writer of 0.
; Re-check before acting: trigger9.g may have extended the run-on between the fire and this
; macro - the trigger fires again when the new run-on ends.
if global.fan_exhaust_until > 0 && state.upTime >= global.fan_exhaust_until
  M106 P3 S{(job.file.fileName != null && global.fan_exhaust_job_value >= 0) ? global.fan_exhaust_job_value : 0}
  set global.fan_exhaust_until = 0
  set global.fan_exhaust_job_value = -1
