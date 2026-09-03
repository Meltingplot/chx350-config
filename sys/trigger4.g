; reevaluate if the global.potential_unsafe_state check is really needed
; as this could lead to the following
; machine ist starting a print job
; machine is heating
; user is opening a door (potential unsafe state = false as no axis is moving)
;

if global.debug
  echo "trigger4 executed"

; Double-check that the doors were truly opened and not triggered by an EMI event, as this could have serious consequences and lead to a print failure.
; The added delay is negligible (<10 ms)
if global.machine_mode != "default" && (sensors.gpIn[2].value == 0 || sensors.gpIn[3].value == 0)
  if global.machine_mode != "default" && (sensors.gpIn[2].value == 0 || sensors.gpIn[3].value == 0)
    ; the mode switch from automatic to default must be instantaneously, if it is not possible due to current motion, halt the machine 
    if global.potential_unsafe_state == true
      echo "Error: potential unsafe state in default mode detected - machine halt!"
      M98 P"0:/sys/meltingplot/set_led_color" C"yellow" E1
      M112

    ; save heater states before switching to default mode
    set global.saved_bed_heater_state = heat.heaters[0].state
    while iterations < #tools
      set global.saved_tool_heater_states[iterations] = heat.heaters[tools[iterations].heaters[0]].state

    ; just do the switchover without any checks may cause a failed print if the printer is not paused due to motion system lock via M599
    ; or may lockup the trigger queue due to waiting for motion system lock - but daemon will guard us if motion happens, it will halt the machine
    M98 P"0:/sys/meltingplot/ce-declaration/operating-mode/default.g"
