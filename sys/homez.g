M98 P"0:/sys/meltingplot/ensure_safety"

; this check is used when called from homeall.g
if move.axes[2].homed == false 
  M98 P"0:/sys/meltingplot/align_z_axis.g"  ; align z axis

if move.axes[0].homed == false            ; check if x is homed
  M98 P"0:/sys/homex.g"                   ; home x axis
if move.axes[1].homed == false            ; check if y is homed
  M98 P"0:/sys/homey.g"                   ; home y axis
if move.axes[3].homed == false            ; check if u is homed
  M98 P"0:/sys/homeu.g"                   ; home u axis

G90 G1 X{move.axes[0].max/2} Y{move.axes[1].max/2} U{move.axes[3].max} F60000
G90 G1 Z200 F6000
M400
M98 P"0:/sys/meltingplot/nozzle-cleaner/clean.g"
G90 G1 Z20 F6000
G90 G1 Z{sensors.probes[0].triggerHeight + sensors.probes[0].diveHeights[0] * 1.5} F600 ; drive close to dive height
; if bed heater is active and above 60 °C - wait a bit for the heat to reach the toolhead	
if heat.heaters[0].active >= 60 && heat.heaters[0].state == "active" && sensors.analog[4].lastReading <= 40
  G4 S30  ; wait 30 seconds for the heat to reach the toolhead, that the z-probe can work properly
M400
M98 P"0:/sys/meltingplot/z-probe/szp_touch_mode.g"
M400
M98 P"0:/sys/meltingplot/probe_current_positon"
if global.result != 0
  M98 P"0:/sys/meltingplot/nozzle-cleaner/clean.g"
  M98 P"0:/sys/meltingplot/probe_current_positon"
if global.result > 1
  echo "Error: Homing Z - abort! global.result: " ^ global.result
  M18 Z
  M99
M400

M98 P"0:/sys/meltingplot/z-probe/szp_standard_mode.g"

M558.1 K0 S1.7
if result != 0
  echo "M558.1 - retry"
  M558.1 K0 S1.7
    if result != 0
      set global.result = 1
      echo "Error: Homing Z - abort! global.result: " ^ global.result
      M18 Z
      M99

M98 P"0:/sys/bed.g"

if global.result != 0
  echo "Error: Homing Z - abort! global.result: " ^ global.result
  M18 Z
  M99

G90 G1 Z200 F6000 ; move bed lower, that the user can see the bed surface
