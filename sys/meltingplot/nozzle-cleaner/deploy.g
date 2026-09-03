if global.debug
  echo "deploy.g"

var clearanceHeight = 50

set global.result = 0

; e.g. 800 - 750 < 50

if job.file.fileName != null && (move.axes[2].max - move.axes[2].machinePosition) < var.clearanceHeight
  echo "Error: not enough clearance to deploy nozzle cleaner."
  set global.result = 1
  M400 ; sbc specific
  M99

G1 F6000
G90

if move.axes[2].machinePosition < 200
  G53 G1 Z200
  M400

; give an additional clearance e.g. while printing
G91 G1 Z45
M400

M42 P6 S1 ; enable servo

M280 P6 S14
G4 P500
M400 ; sbc specific