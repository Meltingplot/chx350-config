if global.debug
  echo "clean.g"

if state.status == "simulating"
  M99

if move.axes[0].homed == false || move.axes[1].homed == false || move.axes[2].homed == false || move.axes[3].homed == false            ; check if u is homed
  M98 P"0:/sys/meltingplot/nozzle-cleaner/retract.g"
  echo "Error: Nozzle Cleaner insufficient axes homed" 
  M99

if global.machine_mode != "automatic"
  echo "Nozzle cleaner is only used in automatic mode!"
  M99

set global.result = 0
M400 ; sbc specific
var pos_x = move.axes[0].machinePosition
var pos_y = move.axes[1].machinePosition
var pos_z = move.axes[2].machinePosition

M98 P"0:/sys/meltingplot/nozzle-cleaner/deploy.g"
M400
if global.result != 0
  M99

G1 F60000
G90
if move.axes[0].machinePosition < 60
  G1 X60

G1 Y220
G1 X6
G1 Y200
G1 Y120
G1 Y200
G1 Y120
G1 X100
M400

M98 P"0:/sys/meltingplot/nozzle-cleaner/retract.g"

G53 G1 X{var.pos_x} Y{var.pos_y} F60000
G53 G1 Z{var.pos_z} F60000
M400 ; sbc specific