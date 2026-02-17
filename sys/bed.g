; bed.g
; called to perform automatic bed compensation via G32
;
if global.debug
  echo "bed.g"

; initialize
set global.result = 0

G90                                       ; absolute positioning
M561                                      ; clear any bed transform
G29 S2                                    ; Clear height compensation
M290 R0 S0                                ; clear babystepping

if move.axes[0].homed == false            ; check if x is homed
  M98 P"0:/sys/homex.g"                   ; home x axis
if move.axes[1].homed == false            ; check if y is homed
  M98 P"0:/sys/homey.g"                   ; home y axis
if move.axes[3].homed == false            ; check if u is homed
  M98 P"0:/sys/homeu.g"                   ; home u axis
if move.axes[2].homed == false            ; check if z is homed
  echo "Error: bed.g insufficient axes homed"
  set global.result = 1                   ; indicate error
  M99

M98 P"0:/sys/meltingplot/z-probe/szp_standard_mode.g"
if global.result != 0
  echo "Error: bed.g failed to set z-probe to standard mode"
  M99

G90                                       ; absolute positioning
G1 Z20 F6000                              ; lift Z to safe height
G1 Z{sensors.probes[0].diveHeights[0] + sensors.probes[0].triggerHeight} F600 ; drive close to dive height

var pos_variation_x = mod(state.msUpTime,16) ; 0 - 15
var pos_variation_y = (mod(state.msUpTime,16)+8)-16 ; -8 - +7

while true
  G30 P0 X{sensors.probes[0].offsets[0]*2+var.pos_variation_x} Y{move.kinematics.tiltCorrection.screwY[0]+var.pos_variation_y} Z-99999      ; probe near a leadscrew, half way along Y axis
  if result != 0
    echo "Warning: G32 - repeat p0"
    G30 P0 X{sensors.probes[0].offsets[0]*2+var.pos_variation_x} Y{move.kinematics.tiltCorrection.screwY[0]+var.pos_variation_y} Z-99999      ; probe near a leadscrew, half way along Y axis
    if result != 0
      echo "Error: G32 - error!"
      set global.result = result
      M99
    echo "G32: p0 ok"
  G30 P1 X{sensors.probes[0].offsets[0]*2+var.pos_variation_x} Y{move.kinematics.tiltCorrection.screwY[1]+var.pos_variation_y} Z-99999      ; probe near a leadscrew, half way along Y axis
  if result != 0
    echo "Warning: G32 - repeat p1"
    G30 P1 X{sensors.probes[0].offsets[0]*2+var.pos_variation_x} Y{move.kinematics.tiltCorrection.screwY[1]+var.pos_variation_y} Z-99999      ; probe near a leadscrew, half way along Y axis
    if result != 0
      echo "Error: G32 - error!"
      set global.result = result
      M99
    echo "G32: p1 ok"
  G30 P2 X{move.axes[0].max-sensors.probes[0].offsets[0]*2-var.pos_variation_x} Y{move.kinematics.tiltCorrection.screwY[2]+var.pos_variation_y} Z-99999               ; probe near a leadscrew, half way along Y axis
  if result != 0
    echo "Warning: G32 - repeat p2"
    G30 P2 X{move.axes[0].max-sensors.probes[0].offsets[0]*2-var.pos_variation_x} Y{move.kinematics.tiltCorrection.screwY[2]+var.pos_variation_y} Z-99999               ; probe near a leadscrew, half way along Y axis
    if result != 0
      echo "Error: G32 - error!"
      set global.result = result
      M99
    echo "G32: p2 ok"
  G30 P3 X{move.axes[0].max-sensors.probes[0].offsets[0]*2-var.pos_variation_x} Y{move.kinematics.tiltCorrection.screwY[3]+var.pos_variation_y} Z-99999 S4            ; probe near sec. leadscrew
  if result != 0
    if iterations > 2
      echo "Error: G32 - error!"
      set global.result = result
      M99
    else
      echo "Warning: G32 - full repeat at p3"
      continue
  elif move.calibration.initial.deviation > 0.03 && iterations < 3 ; it should just try
    continue
  else
    break

; check if probing z was requested
if !exists(param.S) || param.S == 0
  G90
  G1 Z20 F6000
  G1 X{move.axes[0].max/2} Y{move.axes[1].max/2} U{move.axes[3].max} F60000
  G1 Z{sensors.probes[0].diveHeights[1]} F600 ; drive close to dive height
  M98 P"0:/sys/meltingplot/z-probe/szp_touch_mode.g" ; set z-probe to touch mode
  M98 P"0:/sys/meltingplot/probe_current_positon" ; probe current position
  if global.result != 0
    M98 P"0:/sys/meltingplot/nozzle-cleaner/clean.g"
    M98 P"0:/sys/meltingplot/probe_current_positon"
    if global.result != 0
      echo "Error: G32 failed!"
      M99
    echo "G32: z probe ok"

echo "G32 completed successfully"
