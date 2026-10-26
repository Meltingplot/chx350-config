; Door edge - pin trigger T9 (config.g, only with has_exhaust_fan): exhaust run-on. Fires on
; every edge of both door switches, behind trigger3.g and trigger4.g (the lower number runs
; first). A door opened while a tool has a material set up that asks for a run-on
; (fan_exhaust_run_on[], from filament_exhaust_run_on in the profile's config-override.g,
; taken over by filament/on-config.g) runs the exhaust at full speed until
; global.fan_exhaust_until; opening a door again extends it.
; During a job (also paused) the run-on ends as soon as both doors are closed again, and the
; exhaust goes back to the value the job had set. After a job it runs to its end, also with
; the doors closed.
; trigger10.g ends every run-on: this macro moves fan_exhaust_until later or to now, never to
; 0 (config.g, T10). Nothing in here may block - trigger3.g and trigger4.g wait behind it.
if sensors.gpIn[2].value == 0 || sensors.gpIn[3].value == 0
  var run_on = max(global.fan_exhaust_run_on[0], global.fan_exhaust_run_on[1])
  if var.run_on > 0
    if global.fan_exhaust_until == 0
      set global.fan_exhaust_job_value = fans[3].requestedValue
    set global.fan_exhaust_until = max(global.fan_exhaust_until, state.upTime + var.run_on)
    M106 P3 S{1}                                          ; {} keeps it out of the job's queue, where it would wait for the queued moves
elif global.fan_exhaust_until > 0 && job.file.fileName != null
  set global.fan_exhaust_until = state.upTime             ; both doors closed during a job: trigger10.g gives the exhaust back to the job
