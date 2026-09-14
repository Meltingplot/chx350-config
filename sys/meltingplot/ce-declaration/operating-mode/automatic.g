M566 X720.0 Y720.0 Z72.00 U720.0 E1800.00 P1            ; set maximum instantaneous speed changes (mm/min) and apply jerk on every move
M203 X50000.00 Y60000.00 Z1800.00 U60000 E3000.00       ; set maximum speeds (mm/min)
M201 X6000.00 Y6000.00 Z400.00 U6000 E3000.00           ; set accelerations (mm/s^2)
M201.1 X500 Y500 U500 Z100 E1000                        ; set homing accelerations (mm/s^2)
M204 P4000 T6000                                        ; Set printing and travel accelerations
M906 X2500 Y2500 Z1500 U2500 E1400                      ; set motor currents (mA) and motor idle factor in per cent
M906 I30 S30                                            ; Set idle timeout

M917 X70 Y70 U70                                        ; set reduced current for X, Y and U
M917 Z70                                                ; set reduced current for Z
M917 E70                                                ; set reduced current for E

M915 Z S15 F1 R0                                        ; stall detection for high current

M599 Z-1:-1 S0                                          ; clear keepout zone
M400 ; dsf specific
M302 P0 S160 R90                                        ; allow extrusion again

M143 H0 S120 A0 ; revert to default value
M143 H1 S300 A0 ; revert to default value

if state.currentTool != -1
  ; run /filaments/<filament name>/config.g
  M703

set global.machine_mode = "automatic"
echo "Automatic Mode"