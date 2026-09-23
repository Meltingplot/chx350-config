if global.debug
  echo "z-probe/touch-mode.g"

if sensors.analog[4].lastReading > global.szp_warm_threshold
  M98 P"0:/sys/generated/szp-touch-mode-warm.g"
else
  M98 P"0:/sys/generated/szp-touch-mode-cold.g"

if fileexists("0:/sys/generated/szp-touch-z-offset.g")
  M98 P"0:/sys/generated/szp-touch-z-offset.g"

M558 K0 H2 F500:200:6000; dive height
M558.3 K0 S1 V1.2 H{global.szp_touch_z_offset}; touch mode — H is assumed nozzle Z at touch (less negative = closer to bed)
M558 K0 A2 S0.05; probe two times and average