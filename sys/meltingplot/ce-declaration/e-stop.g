;M950 P0 C"out0"                                         ; Configure P0 as output for 24V/48V Relais
M81 C"out0"                                              ; disable ATX power supply

; check if VIN is < 1.65V

; after reboot the rail may be energized - wait max 5 sec
while boards[0].vIn.current > 3.3/2
  if iterations > 200
    echo "Error: 24V rail is active at startup! Current: " ^ boards[0].vIn.current
    M112
  G4 P25

;M42 P0 S1                                               ; enable relais
M80                                                      ; enable ATX power supply

; wait for the 24V rail to come up 80%
while boards[0].vIn.current < 19.2
  if iterations > 200
    echo "Error: 24V rail is not active! Current: " ^ boards[0].vIn.current
    M112
    break
  G4 P25

M950 J0 C"io3.in"                                      ; create e-stop
M950 J1 C"io4.in"                                      ; create second e-stop channel
M581 T2 P0:1 S0 R0                                     ; configure E0 as emergency stop

;M117 "Enable E-Stop Check in Production! Go to /sys/meltingplot/ce-declaration and enable M582"
M582 T2                                                 ; check external e-stop, break if already hit