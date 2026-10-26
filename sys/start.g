; start.g 
; is run when you start a print from SD card. Runs immediately before any slicer created gcode

if state.status == "simulating"
  if ("" ^ global.machine_mode) != "automatic"   ; hardened read, see globals
    echo "Error: simulation requires automatic mode - close both doors and verify door switches first"
    M2
  ; confirm the guard (globals, "CONFIRMING") - a guard that is skipped protects nothing
  if ("" ^ global.machine_mode) != "automatic"
    echo "Error: automatic mode not confirmed on re-read - simulation aborted"
    M2
  M99

; Coolant loop (fan/check-coolant.g): a fan of the water loop that stands still refuses the
; job. A print that already runs goes on - the machine also cools passively - but no new one
; starts until the fan runs again. A fan suspected just now is sampled once more 5 s later,
; so a radiator that started a moment ago is not taken for stalled. A radiator only runs
; with the hotend above 40 C, so a stall seen on it stays until the hotend is hot again.
M98 P"0:/sys/meltingplot/fan/check-coolant.g" S1
if global.result > 0
  G4 S5
  M98 P"0:/sys/meltingplot/fan/check-coolant.g"
if #global.fan_stalled > 0
  var names = ""
  while iterations < #global.fan_stalled
    set var.names = var.names ^ (iterations > 0 ? ", " : "") ^ fans[global.fan_stalled[iterations]].name
  M118 P0 S{"Error: coolant loop fan stands still (" ^ var.names ^ ") - print job not started"}
  M291 R"Kühlkreis" P{"Lüfter steht: " ^ var.names ^ ". Kein neuer Druck, bis er wieder läuft. Radiatorlüfter laufen erst ab 40 °C am Hotend - nach der Reparatur vorheizen und neu starten."} S1 T0
  M0
  M99

; Spool tracker (spool/track.g): RRF zeroed every extruder position right before this
; file (GCodes.cpp StartPrinting) - re-base on that zero before anything extrudes, the
; door prompt below lets the operator extrude from DWC. Arms the report of what is left,
; which the first print/finish.g flush of this job gives.
set global.spool_track_baseline = vector(2, 0.0)
set global.spool_report_pending = true

; Timelapse (timelapse/take-photo.g): the photo position is set anew by the job's first photo.
set global.timelapse_park_x = -1
set global.timelapse_park_z = -1

; Exhaust run-on (trigger9.g): in a job the slicer sets the exhaust (P3), starting from off. A
; run-on left from before the job ends here - trigger10.g switches the fan off, only it writes
; 0. Opening the doors for the check below starts a run-on of its own, which ends when they
; close.
set global.fan_exhaust_job_value = 0
if global.fan_exhaust_until > 0
  set global.fan_exhaust_until = state.upTime

M98 P"0:/sys/meltingplot/ce-declaration/doors/ensure-checked-closed.g"