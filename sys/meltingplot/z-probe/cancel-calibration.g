; z-probe/cancel-calibration.g
; Restores a safe state when the operator cancels macro calibration/z-height at one of its
; prompts. Until the gauge reading has set the datum, the macro works in a frame shifted by
; G92 Z20 at Z120 (reported = gap - 100), and its jog step turns the soft limits off.
;   M98 P"0:/sys/meltingplot/z-probe/cancel-calibration.g" S100
; S = the shift still applied: 100 before the gauge reading, 0 once G92 Z{100 + reading} has set
; the datum. The jog moves happen in the same frame, so adding S back is exact.

M564 S1                                         ; soft limits on again (the jog step turns them off)
if exists(param.S) && param.S != 0
  G92 Z{move.axes[2].userPosition + param.S}    ; back to the homed frame
M568 P0 A0                                      ; nozzle heater off
M140 S-273.15                                   ; bed heater off
; "Error:" marks the macro as not completed for the caller (the CHX 350 UI shows it)
echo "Error: Z-height calibration cancelled by the operator"
