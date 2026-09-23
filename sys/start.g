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

; Spool tracker (spool/track.g): RRF zeroed every extruder position right before this
; file (GCodes.cpp StartPrinting) - re-base on that zero before anything extrudes, the
; door prompt below lets the operator extrude from DWC. Arms the report of what is left,
; which the first print/finish.g flush of this job gives.
set global.spool_track_baseline = vector(2, 0.0)
set global.spool_report_pending = true

M98 P"0:/sys/meltingplot/ce-declaration/doors/ensure-checked-closed.g"