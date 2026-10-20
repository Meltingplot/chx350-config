; z-probe/cancel-calibration.g
; Restores a safe state when macro calibrate_z_height_automatic ends early because a step
; failed. z-probe/scan-contact.g and calibrate.g lower the bed off the nozzle themselves; this puts
; the soft limits back and switches the heaters off, so a machine running the calibration
; unattended does not hold 250 C and 90 C after a failed run. The failing step has echoed
; its reason before.
;   M98 P"0:/sys/meltingplot/z-probe/cancel-calibration.g"

M564 S1                                         ; soft limits on again (z-probe/scan-contact.g turns them off)
M568 P0 A0                                      ; nozzle heater off
M140 S-273.15                                   ; bed heater off
if state.messageBox != null                     ; the progress box of the failed step would stay open
  M292
echo "Error: Z-height calibration aborted"
