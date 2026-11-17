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
    ; restore tool heaters to saved state - by M568 P<tool>, never by selecting a tool.
    ; This trigger can run in the middle of a tool change on another channel: the door
    ; prompts (ensure_safety, check_doors_closed, reached from tpre0.g) are blocking M291s,
    ; which release the movement lock, and RRF keeps the target of a tool change per motion
    ; system (newToolNumber), not per channel. A T here re-targets the pending change -
    ; the DWC filament load after a boot (T0 -> door check -> doors closed -> this trigger)
    ; ended with no tool selected, and M701 failed with "No tool selected".
    ; The cap default mode set (M143 S50) was lifted by automatic.g before this point:
    ; config.g's limits, and M703 - the filament's own cap - for the selected tool. A
    ; deselected tool gets its filament cap back at its next selection (tpost0.g -> M703);
    ; a saved setpoint above the cap it has now is left off with a warning.
    while iterations < #tools
      var heater = tools[iterations].heaters[0]
      if global.saved_tool_heater_states[iterations] == "active"
        if heat.heaters[var.heater].active > heat.heaters[var.heater].max
          M118 P0 S{"Warning: tool " ^ iterations ^ " active " ^ heat.heaters[var.heater].active ^ "C is above its limit " ^ heat.heaters[var.heater].max ^ "C - heater left off, select the tool"}
        else
          M568 P{iterations} A2
      elif global.saved_tool_heater_states[iterations] == "standby"
        if heat.heaters[var.heater].standby > heat.heaters[var.heater].max
          M118 P0 S{"Warning: tool " ^ iterations ^ " standby " ^ heat.heaters[var.heater].standby ^ "C is above its limit " ^ heat.heaters[var.heater].max ^ "C - heater left off, select the tool"}
        else
          M568 P{iterations} A1
    ; clear saved state
    set global.saved_bed_heater_state = "off"
    while iterations < #tools
      set global.saved_tool_heater_states[iterations] = "off"