; confirm_nozzle_diameter.g
; Asks the operator which nozzle is installed, as a dropdown with the currently configured
; diameter preselected. Called from load_filament_sensorless right before the physical
; load - after a filament change has been triggered, but before calibrate_e_steps runs:
; the calibration writes filaments/<name>/config-auto-esteps-<key>.g and the NLE check
; right after it looks up config-auto-nle-<key>.g, so a stale diameter would file the
; measurement under the wrong nozzle and read back another nozzle's calibration.
;   M98 P"0:/sys/meltingplot/confirm_nozzle_diameter.g" T0
; T<tool> is optional and defaults to the current tool. Cancelling keeps the configured
; value: this is a confirmation, not a mandatory step, and must never abort a load - hence
; J2 (result = -1, execution continues) and never J1 (which kills the whole file stack).
; A changed diameter is persisted by store_nozzle_diameter.g and applied to the loaded
; filament by load_nozzle_config.g - NOT by M703: this macro runs from inside the profile's
; config.g (M703 -> config.g -> load_filament_sensorless_conditionally.g ->
; load_filament_sensorless), so M703 here would re-enter the file that is executing.
; A profile that has no filaments/<name>/nozzle-<key>.g for the confirmed diameter yet is
; offered one here (create_nozzle_config.g), which is the last point where the operator
; can still supply the values before they are needed.

if global.debug
  echo "confirm_nozzle_diameter.g"

var tool = exists(param.T) ? ((param.T == 1) ? 1 : 0) : min(max(state.currentTool, 0), 1)

; two decimals of fixed width - see globals: the raw float must never build a file name.
; sformat.g returns the key in global.result - read it straight away
M98 P"0:/sys/meltingplot/sformat.g" F{global.nozzle_diameter[var.tool]} D2 W0
var key = global.result

; preselect the configured nozzle; a diameter that is not in the list preselects "Other..."
var choice = 5
if var.key == "0.40"
  set var.choice = 0
elif var.key == "0.60"
  set var.choice = 1
elif var.key == "0.80"
  set var.choice = 2
elif var.key == "1.00"
  set var.choice = 3
elif var.key == "1.20"
  set var.choice = 4

M291 R"Nozzle diameter" P{"Which nozzle is installed on tool " ^ var.tool ^ "?"} S4 K{"0.40 mm","0.60 mm","0.80 mm","1.00 mm","1.20 mm","Other..."} F{var.choice} J2
if result != 0             ; J2 leaves input undefined - result must be tested right here
  M99
set var.choice = input

var diameter = global.nozzle_diameter[var.tool]
if var.choice == 0
  set var.diameter = 0.4
elif var.choice == 1
  set var.diameter = 0.6
elif var.choice == 2
  set var.diameter = 0.8
elif var.choice == 3
  set var.diameter = 1.0
elif var.choice == 4
  set var.diameter = 1.2
else
  M291 R"Nozzle diameter" P{"Nozzle diameter of tool " ^ var.tool ^ " in mm:"} S6 L0.1 H2 F{global.nozzle_diameter[var.tool]} J2
  if result != 0
    M99
  set var.diameter = input

var filament = move.extruders[tools[var.tool].extruders[0]].filament

; The operator has just selected this profile and is standing at the machine, so this is
; the moment to offer the nozzle parameters when the profile has none for this diameter -
; create_nozzle_config.g asks and writes filaments/<name>/nozzle-<key>.g, and the values
; then apply to the load, the e-steps calibration and the NLE check that follow. The
; offer sits here and not in load_nozzle_config.g because that one also runs from the
; generated config.g during print_start, pause.g and resume.g, where it must not block.
; global.result of the call is only valid on the very next line: 0 = a file was written.
if var.diameter == global.nozzle_diameter[var.tool]
  ; confirmed unchanged - nothing to persist and nothing to re-apply unless the offer
  ; above actually produced a file
  if var.filament != ""
    M98 P"0:/sys/meltingplot/create_nozzle_config.g" S{var.filament} T{var.tool}
    if global.result == 0
      M98 P"0:/sys/meltingplot/load_nozzle_config.g" S{var.filament}
  M99

M98 P"0:/sys/meltingplot/store_nozzle_diameter.g" D{var.diameter} T{var.tool}
set var.key = global.result

; the nozzle-dependent parameters (max volumetric flow rate, M572, M207, M309) live in
; filaments/<name>/nozzle-<key>.g - re-run that selection so the new nozzle takes effect
; for the load and the e-steps calibration that follow. Unconditional here: the diameter
; changed, so the values of the previous nozzle are still active either way.
if var.filament != ""
  M98 P"0:/sys/meltingplot/create_nozzle_config.g" S{var.filament} T{var.tool}
  M98 P"0:/sys/meltingplot/load_nozzle_config.g" S{var.filament}

M118 P0 S{"Tool " ^ var.tool ^ " set to " ^ var.key ^ "mm - check the Z offset and calibrate PA/NLE for this nozzle"}
