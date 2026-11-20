; the drive current (S) is important to get a stable reading. Measured on the lab machine
; (2026-10-28, bed centre, R0, Z600 down to Z1 cold and to Z1.5 with the coil at 70-74 C):
; S15 and S16 read at every height, cold and warm; warm, S14 fails from Z5 down, S17 at Z600,
; S18 reads only from Z2 down; cold, S17 and up read nowhere; S13 and S20 and up read nowhere.
; calibration/z-height stores the middle of the window that reads valid from Z12 down to Z1.8
; (z-probe/calibrate.g); a missing file is reported once per boot by the quick self-test
; (self-test/check-quick.g), not at every call

if global.debug
  echo "z-probe/standard-mode.g"

if sensors.analog[4].lastReading > global.szp_warm_threshold
  M98 P"0:/sys/generated/szp-standard-mode-warm.g" T{sensors.analog[4].lastReading}
else
  M98 P"0:/sys/generated/szp-standard-mode-cold.g"

G31 K0 Z3 P9000 ; trigger height 3mm, trigger value 9000
M558 K0 H6 A1 F6000:200:20000; dive height

M558.3 K0 S0 ; standard mode
