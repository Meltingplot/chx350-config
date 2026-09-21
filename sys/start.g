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

M98 P"0:/sys/meltingplot/ensure_safety"