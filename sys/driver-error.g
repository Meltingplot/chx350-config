; driver-error.g
; called to home x, y and u after stall detection
; driver error - 51.0 : 3072 ,Driver 51.0 error: failed to maintain position

if global.debug
  echo "driver error - "^{param.B}^"."^{param.D}^" : "^{param.P}^" ,"^{param.S}

if exists(global.closed_loop_homing) && global.closed_loop_homing
  M99

if param.B > 0 && param.D == 0 && param.P == 3072 && move.axes[0].homed == false && move.axes[1].homed == false
  M99 ; ignore warning when drives are not homed

if global.debug == false
  echo "driver error - "^{param.B}^"."^{param.D}^" : "^{param.P}^" ,"^{param.S}

if job.file.fileName != null
  M25 ; pause print