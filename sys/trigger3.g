; THIS FILE CONTAINS CE RELEVANT CONFIGURATIONS, ANY CHANGES TO THIS FILE MAY RESULT IN A LOST OF THE CE DECLARATION
if global.debug
  echo "trigger3.g executed"
  echo "global.machine_mode: " ^ global.machine_mode

; Tier-1 flags are bit-flip hardened and read through the "" ^ coercion (see globals):
; switch_checked is "checked" only by exact match with "1431655765" (0x55555555)
if(sensors.gpIn[2].value == 1 && sensors.gpIn[3].value == 1 && ("" ^ global.door_left_switch_checked) == "1431655765" && ("" ^ global.door_right_switch_checked) == "1431655765")
  ; Confirm the gate with the inverse comparison before waiting for automatic mode and
  ; restoring the heaters (globals, "CONFIRMING"). The sensors are re-read as well - this
  ; trigger fires on the door-closed edge, exactly where an EMI blip is plausible, though
  ; only the flag re-reads are guaranteed fresh values.
  ; Returning is restrictive - the daemon re-evaluates the interlock every iteration.
  if sensors.gpIn[2].value != 1 || sensors.gpIn[3].value != 1 || ("" ^ global.door_left_switch_checked) != "1431655765" || ("" ^ global.door_right_switch_checked) != "1431655765"
    M118 P0 S"Warning: doors not confirmed closed on re-read - heater restore skipped"
    M99
  M400
  G4 P500 ; wait for the switch to automatic mode
  while ("" ^ global.machine_mode) != "automatic" && iterations < 5
    M400
    G4 P500
  if ("" ^ global.machine_mode) == "automatic"
    ; confirm before re-enabling the heaters, see above
    if ("" ^ global.machine_mode) != "automatic"
      M118 P0 S"Warning: automatic mode not confirmed on re-read - heater restore skipped"
      M99
    ; restore bed heater to saved state. Only "active"/"standby" are restorable; any other
    ; value (corrupted, or an OM state such as "fault"/"offline") leaves the heater off
    if ("" ^ global.saved_bed_heater_state) == "active"
      M144 P0 S1
    elif ("" ^ global.saved_bed_heater_state) == "standby"
      M144 P0 S0
    elif ("" ^ global.saved_bed_heater_state) != "off"
      M118 P0 S{"Warning: saved bed heater state '" ^ global.saved_bed_heater_state ^ "' is not restorable - bed left off"}
    ; restore tool heaters to saved state - by M568 P<tool>, never by selecting a tool.
    ; This trigger can run in the middle of a tool change on another channel: the door
    ; prompts (ce-declaration/doors/*.g, reached from tpre0.g) are blocking M291s, which
    ; release the movement lock, and RRF keeps the target of a tool change per motion
    ; system (newToolNumber), not per channel. A T here re-targets the pending change -
    ; the DWC filament load after a boot (T0 -> door check -> doors closed -> this trigger)
    ; ended with no tool selected, and M701 failed with "No tool selected".
    ; The cap default mode set (M143 S50) was lifted by automatic.g before this point:
    ; config.g's limits, and M703 - the filament's own cap - for the selected tool. A
    ; deselected tool gets its filament cap back at its next selection (tpost0.g -> M703);
    ; a saved setpoint above the cap it has now is left off with a warning.
    while iterations < #tools
      var heater = tools[iterations].heaters[0]
      if ("" ^ global.saved_tool_heater_states[iterations]) == "active"
        if heat.heaters[var.heater].active > heat.heaters[var.heater].max
          M118 P0 S{"Warning: tool " ^ iterations ^ " active " ^ heat.heaters[var.heater].active ^ "C is above its limit " ^ heat.heaters[var.heater].max ^ "C - heater left off, select the tool"}
        else
          M568 P{iterations} A2
      elif ("" ^ global.saved_tool_heater_states[iterations]) == "standby"
        if heat.heaters[var.heater].standby > heat.heaters[var.heater].max
          M118 P0 S{"Warning: tool " ^ iterations ^ " standby " ^ heat.heaters[var.heater].standby ^ "C is above its limit " ^ heat.heaters[var.heater].max ^ "C - heater left off, select the tool"}
        else
          M568 P{iterations} A1
      elif ("" ^ global.saved_tool_heater_states[iterations]) != "off"
        M118 P0 S{"Warning: saved heater state of tool " ^ iterations ^ " '" ^ global.saved_tool_heater_states[iterations] ^ "' is not restorable - heater left off"}
    ; clear saved state
    set global.saved_bed_heater_state = "off"
    while iterations < #tools
      set global.saved_tool_heater_states[iterations] = "off"