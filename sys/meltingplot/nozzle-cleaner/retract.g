if global.debug
  echo "retract.g"

M42 P6 S1 ; enable servo
M280 P6 S103 ; retract nozzle cleaner
G4 S1 ; wait for servo to move
M42 P6 S0 ; disable servo