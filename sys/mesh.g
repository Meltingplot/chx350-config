M98 P"0:/sys/meltingplot/ce-declaration/doors/ensure-checked-closed.g"         ; ensure safety conditions are met
G29 S2                                          ; Clear height compensation
M290 R0 S0                                      ; clear babystepping
M116                                            ; wait for all heaters

set global.result = 0

G90                                             ; absolute positioning
G1 Z20 F6000                                    ; move Z up to 20mm
G1 X{move.axes[0].max/2} Y{move.axes[1].max/2} U{move.axes[3].max} F60000
G1 Z{sensors.probes[0].diveHeights[0]} F600 ; drive close to dive height

; standard mode with the drive current and reading offset calibration/z-height measured for
; this coil temperature (z-probe/calibrate.g: the middle of the window that reads valid from
; Z12 down to Z1.8, the bottom of the M558.1 below). Until 2026-11 an M558.2 S-1 here let the
; LDC1612 pick a current at Z3 that nothing checked; it picked S16 at every mesh on the lab
; machine. No G31 P here: M558.1 sets the threshold to its reading at the trigger height, the
; reference of the height curve (RRF ZProbe::CalibrateScanningProbe)
M98 P"0:/sys/meltingplot/z-probe/standard-mode.g"

G90 G1 Z{sensors.probes[0].triggerHeight + sensors.probes[0].diveHeights[0]}
M400
G4 S1                                           ; let the sensor settle on the drive current standard-mode.g set

M558.1 K0 S1.2
if result != 0
  echo "M558.1 - retry"
  G90 G1 Z{sensors.probes[0].triggerHeight + sensors.probes[0].diveHeights[0]}
  M400
  M558.1 K0 S1.2
  if result != 0
    set global.result = 1
    echo "Error: G29 failed!"
    M99

G1 Z{sensors.probes[0].diveHeights[0]} F600 
G29 S0                                          ; create height map
if result != 0
  set global.result = 1
  echo "Error: G29 failed!"
