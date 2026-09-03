; cancel.g
; called when a print is cancelled after a pause.


M98 P"0:/sys/meltingplot/check_doors_closed"
M98 P"0:/sys/meltingplot/print_end"
M98 P"0:/sys/meltingplot/ce-declaration/operating-mode/default.g"
M400 ; bug #1192 workaround