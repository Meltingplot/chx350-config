; the drive current (S) is important to get a stable reading
; S16 is suitable for distance measurement from 0mm to 20mm
; S17 is suitable for distance measurement from 0mm to 3mm

if global.debug
  echo "szp_standard_mode.g"

if sensors.analog[4].lastReading > global.szp_warm_threshold
  M98 P"0:/sys/meltingplot/z-probe/szp_standard_mode_calibration_warm.g" T{sensors.analog[4].lastReading}
else
  M98 P"0:/sys/meltingplot/z-probe/szp_standard_mode_calibration_cold.g"

G31 K0 Z3 P9000 ; trigger height 3mm, trigger value 9000
M558 K0 H6 A1 F6000:200:20000; dive height

M558.3 K0 S0 ; standard mode
