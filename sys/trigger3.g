; THIS FILE CONTAINS CE RELEVANT CONFIGURATIONS, ANY CHANGES TO THIS FILE MAY RESULT IN A LOST OF THE CE DECLARATION
if global.debug
  echo "trigger3.g executed"
  echo "global.machine_mode: " ^ global.machine_mode

; Heater restore after the doors were closed again - expression trigger T3 (ce-declaration.g,
; M581.1): RRF fires it when machine_mode_safe turns to the automatic pattern, i.e. once the
; switch to automatic mode is complete (automatic.g writes the mirror last, after lifting
; default.g's 50 C caps). Nothing to wait for here: as a pin trigger on the door-closed edge
; this macro polled up to 3 s (M400 + G4 P500) for the daemon to finish that switch, holding
; the Trigger channel meanwhile and leaving the heaters off when the switch took longer.
; The expression compares numerically - a string literal in it would be copied into the
; string heap on every main-loop pass. A value that is no number would disable the trigger:
; restrictive, the heaters stay off, and daemon.g halts on such a value anyway. The decision is
; made here, with the hardened reads below.
; Tier-1 flags are bit-flip hardened and read through the "" ^ coercion (see globals):
; switch_checked is "checked" only by exact match with "1431655765" (0x55555555)
if(sensors.gpIn[2].value == 1 && sensors.gpIn[3].value == 1 && ("" ^ global.door_left_switch_checked) == "1431655765" && ("" ^ global.door_right_switch_checked) == "1431655765")
  ; Confirm the gate with the inverse comparison before restoring the heaters (globals,
  ; "CONFIRMING"). The sensors are re-read as well, though only the flag re-reads are
  ; guaranteed fresh values.
  ; Returning is restrictive - the daemon re-evaluates the interlock every iteration.
  if sensors.gpIn[2].value != 1 || sensors.gpIn[3].value != 1 || ("" ^ global.door_left_switch_checked) != "1431655765" || ("" ^ global.door_right_switch_checked) != "1431655765"
    M118 P0 S"Warning: doors not confirmed closed on re-read - heater restore skipped"
    M99
  ; automatic only when the string and its hardened mirror agree (globals, machine_mode_safe)
  if ("" ^ global.machine_mode) == "automatic" && ("" ^ global.machine_mode_safe) == "1431655765"
    ; confirm before re-enabling the heaters, see above
    if ("" ^ global.machine_mode) != "automatic" || ("" ^ global.machine_mode_safe) != "1431655765"
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