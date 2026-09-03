; start.g 
; is run when you start a print from SD card. Runs immediately before any slicer created gcode

if state.status == "simulating"
  if global.machine_mode != "automatic"
    echo "Error: simulation requires automatic mode - close both doors and verify door switches first"
    M2
  M99

M98 P"0:/sys/meltingplot/ensure_safety"