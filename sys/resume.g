; resume.g
; called before a print from SD card is resumed
;

M98 P"0:/sys/meltingplot/ensure_safety"

T R1                    ; put last tool into active
M106 R1                 ; enable fan in its last state

if heat.heaters[tools[0].heaters[0]].current < heat.heaters[tools[0].heaters[0]].active
  M116 P0                 ; wait for T0 only if we need to heat up
G90                          ; absolute positioning
G1 R1 X0 Y0 U0 F60000        ; go above position of the last print move
G1 R1 X0 Y0 U0 Z2.5 F60000   ; go to 2.5mm above position of the last print move
G1 R1 X0 Y0 U0 Z0 F1000      ; go back to the last print move
M83                       ; relative extruder moves

if state.currentTool != -1
  ; Manual forward extrusion on this tool's drive while paused (e.g. purging after
  ; fixing a filament error), measured BEFORE G11 so firmware-retract accounting
  ; cannot skew it. The per-drive position counter accumulates every commanded move
  ; and is not reset by G92 or pause/resume (only at print start), so the delta to
  ; the pause.g snapshot is exactly what was extruded while paused. A drive mismatch
  ; with the snapshot falls back to 0 (= full re-prime, the previous behavior).
  var drive = tools[state.currentTool].extruders[0]
  var manual_e = var.drive == global.pause_extruder ? max(0.0, move.extruders[var.drive].position - global.pause_extruder_pos) : 0.0
  G11                       ; unretract
  ; Re-prime the pause retract minus the manual extrusion — the full 12.7mm on top of
  ; an already primed melt zone would grind immediately. Extra manual retraction is
  ; NOT re-fed (clamped to 0..12.7): a short seam gap is safer than regrinding.
  G1 E{max(0.0, 12.7 - var.manual_e)} F2000

; Re-assert a pending MFM flow-bias e-steps correction. Resuming re-selects the tool (T R1 above),
; which reloads e-steps from the filament config and wipes any M92 applied in filament-error.g — so
; re-apply the corrected value here, after the reload, to make it win. Idempotent (suggested is the
; fixed, clamped target); capture the baseline (now the reloaded config value) if not yet recorded
; so print_end can restore it. Standstill here, so the blocking M92 is fine.
if global.mfm_esteps_suggested != 0
  if global.mfm_esteps_baseline == 0
    set global.mfm_esteps_baseline = move.extruders[0].stepsPerMm
  M92 E{global.mfm_esteps_suggested}

M400 ; sbc specific