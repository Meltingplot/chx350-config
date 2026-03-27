; THIS FILE CONTAINS CE RELEVANT CONFIGURATIONS, ANY CHANGES TO THIS FILE MAY RESULT IN A LOST OF THE CE DECLARATION
if global.debug
  echo "trigger3.g executed"
  echo "global.machine_mode: " ^ global.machine_mode

if(sensors.gpIn[2].value == 1 && sensors.gpIn[3].value == 1 && global.door_left_switch_checked == true && global.door_right_switch_checked == true)
  M400
  G4 P500 ; wait for the switch to automatic mode
  while global.machine_mode != "automatic" && iterations < 5
    M400
    G4 P500
  if global.machine_mode == "automatic"
    ; restore bed heater to saved state
    if global.saved_bed_heater_state == "active"
      M144 P0 S1
    elif global.saved_bed_heater_state == "standby"
      M144 P0 S0
    ; restore tool heaters to saved state
    while iterations < #tools
      if global.saved_tool_heater_states[iterations] == "active"
        M568 P{iterations} A2
      elif global.saved_tool_heater_states[iterations] == "standby"
        M568 P{iterations} A1
    ; clear saved state
    set global.saved_bed_heater_state = "off"
    while iterations < #tools
      set global.saved_tool_heater_states[iterations] = "off"
