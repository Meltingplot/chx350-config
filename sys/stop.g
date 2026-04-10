; stop.g
; called when M0 (Stop) is run (e.g. when a print from SD card is cancelled)
;

if state.status == "simulating"
  M99

M98 P"0:/sys/meltingplot/check_doors_closed"
M98 P"0:/sys/meltingplot/print_end"
M98 P"0:/sys/meltingplot/ce-declaration/operating-mode/default.g"
M400 ; bug #1192 workaround