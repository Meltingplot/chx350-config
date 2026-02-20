M599 X{move.axes[0].min,move.axes[0].max} Y{move.axes[1].min,move.axes[1].max} Z{move.axes[2].min,move.axes[2].max} U{move.axes[3].min,move.axes[3].max} S1 ; set keepout zone
M302 P0 S500 R500                                       ; stop extrusion by cold-extrusion prevention

M566 X12.0 Y12.0 Z12.00 U12.0 E12.0 P1                  ; set maximum instantaneous speed changes (mm/min) and apply jerk on every move
M203 X60.00 Y60.00 Z60.00 U60 E60.00                    ; set maximum speeds (mm/min)
M201 X12.00 Y12.00 Z12.00 U12.00 E12.00                 ; set accelerations (mm/s^2)
M201.1 X12 Y12 U12 Z12 E12                              ; set homing accelerations (mm/s^2)
M204 P500 T1000                                         ; Set printing and travel accelerations
M906 X1400 Y1400 Z1500 U1400 E1100                      ; set motor currents (mA) and motor idle factor in per cent

M84 S30                                                 ; Set idle timeout
M917 X{200/move.axes[0].current*100} Y{200/move.axes[1].current*100} U{200/move.axes[3].current*100} ; set idle current to 200mA for X, Y and U
M917 Z{350/move.axes[2].current*100}                    ; set idle current to 350mA for Z
M917 E50                                                ; set idle current to 50% for E

M915 Z S5 F1 R2                                         ; stall detection for low current

M140 P0 S-273.15                                        ; disable bed heater
while iterations < #tools
  M568 P{iterations} A0                                 ; disable hotend

while iterations < #heat.heaters
  M143 H{iterations} S50 A2                             ; do not allow to turn heater on above 50°C

M400 ; DSF specific

set global.machine_mode = "default"
echo "Default Mode"