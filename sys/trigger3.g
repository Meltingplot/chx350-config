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
    var last_active_tool = state.currentTool
    ; restore bed heater to saved state. Only "active"/"standby" are restorable; any other
    ; value (corrupted, or an OM state such as "fault"/"offline") leaves the heater off
    if ("" ^ global.saved_bed_heater_state) == "active"
      M144 P0 S1
    elif ("" ^ global.saved_bed_heater_state) == "standby"
      M144 P0 S0
    elif ("" ^ global.saved_bed_heater_state) != "off"
      M118 P0 S{"Warning: saved bed heater state '" ^ global.saved_bed_heater_state ^ "' is not restorable - bed left off"}
    ; restore tool heaters to saved state
    while iterations < #tools
      ; select tool without macros
      if var.last_active_tool != iterations
        T T{iterations} P0
      ; run /filaments/<filament name>/config.g
      M703
      if ("" ^ global.saved_tool_heater_states[iterations]) == "active"
        M568 P{iterations} A2
      elif ("" ^ global.saved_tool_heater_states[iterations]) == "standby"
        M568 P{iterations} A1
      elif ("" ^ global.saved_tool_heater_states[iterations]) != "off"
        M118 P0 S{"Warning: saved heater state of tool " ^ iterations ^ " '" ^ global.saved_tool_heater_states[iterations] ^ "' is not restorable - heater left off"}
    ; clear saved state
    set global.saved_bed_heater_state = "off"
    ; restore last active tool. Selecting it activates its heater as a side effect, so
    ; switch it off again unless the saved state says active/standby - a corrupted saved
    ; value must not leave the heater on through that side effect
    if state.currentTool != var.last_active_tool
      T T{var.last_active_tool} P0
      if var.last_active_tool != -1 && ("" ^ global.saved_tool_heater_states[var.last_active_tool]) != "active" && ("" ^ global.saved_tool_heater_states[var.last_active_tool]) != "standby"
        M568 P{var.last_active_tool} A0
    while iterations < #tools
      set global.saved_tool_heater_states[iterations] = "off"