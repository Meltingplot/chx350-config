echo "szp_touch_mode.g"
if sensors.analog[4].lastReading > 40
  M98 P"0:/sys/meltingplot/z-probe/szp_touch_mode_calibration_warm.g"
else
  M98 P"0:/sys/meltingplot/z-probe/szp_touch_mode_calibration_cold.g"

M558 K0 H2 F500:200:6000; dive height
M558.3 K0 S1 V1.2 H-0.1; touch mode with sensitivity H param is added to trigger height, e.g. is H is -0.05 than the nozzle is moved 0.05mm closer to the bed
M558 K0 A2 S0.05; probe two times and average