M98 P"0:/sys/meltingplot/ensure_safety"         ; ensure safety conditions are met
G29 S2                                          ; Clear height compensation
M290 R0 S0                                      ; clear babystepping
M116                                            ; wait for all heaters

set global.result = 0

G90                                             ; absolute positioning
G1 Z20 F6000                                    ; move Z up to 20mm
G1 X{move.axes[0].max/2} Y{move.axes[1].max/2} U{move.axes[3].max} F60000
G1 Z{sensors.probes[0].diveHeights[0]} F600 ; drive close to dive height

M98 P"0:/sys/meltingplot/z-probe/szp_standard_mode.g"
G31 K0 Z3 ; reduce trigger height
M400
G4 P500
G90 G1 Z{sensors.probes[0].triggerHeight}
M400
M558.2 K0 S-1
if result != 0
  echo "M558.2 - retry"
  G1 Z{sensors.probes[0].triggerHeight} F600 ; drive close to dive height
  M400
  M558.2 K0 S-1
  if result != 0
    set global.result = 1
    echo "Error: G29 failed!"
    M99


G90 G1 Z{sensors.probes[0].triggerHeight}
M400
G4 P500
var trigger_value = sensors.probes[0].value[0] 
G31 K0 P{var.trigger_value}

G90 G1 Z{sensors.probes[0].triggerHeight + sensors.probes[0].diveHeights[0]}
M400

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
