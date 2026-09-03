; driver-warning.g
; driver warning - 51.0 : 1024 ,Driver 51.0 warning: position tolerance exceeded

if param.B > 0 && param.D == 0 && param.P == 1024 && move.axes[0].homed == false && move.axes[1].homed == false
  M99 ; ignore warning when drives are not homed

echo "driver warning - "^{param.B}^"."^{param.D}^" : "^{param.P}^" ,"^{param.S}

if state.status == "paused" || state.status == "pausing" || state.status == "resuming"
  M99 ; ignore this event - it is already handled

if !exists(global.event_driver_stall)
  global event_driver_stall = true

; check if a printjob is running 
; if it is a can connected driver in closed loop mode with error position tolerance exceeded (param.B > 0 && param.D == 0 && param.P == 1024)
if job.file.fileName != null
  if param.B > 0 && param.D == 0 && param.P == 1024
    M207 Z{min(1,tools[0].retraction.zHop+0.2)}                                ; raise z-hop 0.2mm to prevent further crashes
