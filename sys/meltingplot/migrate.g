; migrate.g
; Moves the machine-owned files from their pre-3.7 location into the two directories a
; config update never overwrites: the operator-edited overrides into sys/overrides/, the
; files the machine writes itself into sys/generated/. Then deletes the pre-3.7 file
; names that the 3.7 renaming replaced (see CLAUDE.md, "Naming"). Run at boot from
; dsf-config.g and from globals.g, before either reads any of them. Idempotent: once
; nothing is left at the old location it costs a few fileexists lookups and nothing
; else, so the two calls may overlap. Remove once every machine runs 3.7.
;
; D1: a file found at the old location is by definition the machine's own copy - the
; operator's edited override or a value the machine wrote - so it replaces whatever the
; update shipped at the new location (the commented-out template). A machine-written
; file never exists at both places, because nothing writes the new one before this ran.
; M471 does not create the target directory (DSF: File.Move), so sys/generated/ - which
; nothing ships - is created first; M470 on an existing directory is a no-op on DSF.
;
; Several lists, because one would exceed the 255-character limit of a meta-command
; argument.
var shipped = {"global-override.g", "machine-override", "dsf-config-override.g", "printer-name.g"}
var written = {"nozzle0.g", "nozzle1.g", "nozzle-type0.g", "nozzle-type1.g", "filament-diameter0.g", "filament-diameter1.g", "spool0.g", "spool1.g", "bed-surface.g", "last-filament-temp.g"}
; the scanning Z-probe calibration used to live in the code tree (sys/meltingplot/z-probe/)
; and was renamed on the move: szp_old[i] becomes sys/generated/szp_new[i]
var szp_old = {"szp_standard_mode_calibration_warm.g", "szp_standard_mode_calibration_cold.g", "szp_touch_mode_calibration_warm.g", "szp_touch_mode_calibration_cold.g", "szp_touch_z_offset.g"}
var szp_new = {"szp-standard-mode-warm.g", "szp-standard-mode-cold.g", "szp-touch-mode-warm.g", "szp-touch-mode-cold.g", "szp-touch-z-offset.g"}

while iterations < #var.shipped
  if fileexists("0:/sys/meltingplot/" ^ var.shipped[iterations])
    M471 S{"0:/sys/meltingplot/" ^ var.shipped[iterations]} T{"0:/sys/overrides/" ^ var.shipped[iterations]} D1
    M118 P0 S{"moved sys/meltingplot/" ^ var.shipped[iterations] ^ " to sys/overrides/"}

while iterations < #var.written
  if fileexists("0:/sys/meltingplot/" ^ var.written[iterations])
    M470 P"0:/sys/generated"
    M471 S{"0:/sys/meltingplot/" ^ var.written[iterations]} T{"0:/sys/generated/" ^ var.written[iterations]} D1
    M118 P0 S{"moved sys/meltingplot/" ^ var.written[iterations] ^ " to sys/generated/"}

while iterations < #var.szp_old
  if fileexists("0:/sys/meltingplot/z-probe/" ^ var.szp_old[iterations])
    M470 P"0:/sys/generated"
    M471 S{"0:/sys/meltingplot/z-probe/" ^ var.szp_old[iterations]} T{"0:/sys/generated/" ^ var.szp_new[iterations]} D1
    M118 P0 S{"moved z-probe/" ^ var.szp_old[iterations] ^ " to sys/generated/" ^ var.szp_new[iterations]}

; Pre-3.7 names of renamed files. A config update installs the new names but need not
; remove the old ones, and a stale copy is old code: it still reads the renamed globals
; and calls the renamed files. The eight forwarding files (CLAUDE.md, "Deprecated
; forwarding files") keep their old path and are deliberately not in these lists.
var stale_sys1 = {"globals", "migrate_overrides.g", "ensure_safety", "check_doors_closed", "check_door_plausibility", "home_if_necessary", "prime_nozzle_0", "wait_for_heater"}
var stale_sys2 = {"mfm_auto_recovery", "regenerate_filament_config.g", "create_nozzle_config.g", "create_material_config.g", "calibration_key.g", "find_calibration_file.g", "sformat.g"}
var stale_sys3 = {"confirm_nozzle_diameter.g", "store_nozzle_diameter.g", "confirm_nozzle_type.g", "confirm_filament_diameter.g", "confirm_bed_surface.g", "set_led_color"}
var stale_sys4 = {"confirm_spool_size.g", "store_spool.g", "spool_track.g", "load_spool_types.g", "align_z_axis.g", "set_new_z_height", "probe_current_positon"}
var stale_sys5 = {"z-probe/szp_standard_mode.g", "z-probe/szp_touch_mode.g"}
var stale_mac1 = {"drive-cleaner", "meltingplot/align_z_axis", "meltingplot/calibrate_e_steps", "meltingplot/calibrate_nle", "meltingplot/calibrate_pa", "meltingplot/calibrate_z_height_automatic"}
var stale_mac2 = {"meltingplot/create_heightmap", "meltingplot/create_magnetic_table", "meltingplot/maintenance/edit-spool-types", "meltingplot/startup/heatup_and_home.g"}
var stale_mac3 = {"meltingplot/z-probe/offset/apply_babystepping", "meltingplot/z-probe/offset/closer_0.05", "meltingplot/z-probe/offset/farther_0.05"}
var stale = {var.stale_sys1, var.stale_sys2, var.stale_sys3, var.stale_sys4, var.stale_sys5, var.stale_mac1, var.stale_mac2, var.stale_mac3}
var dir = ""

while iterations < #var.stale
  set var.dir = (iterations < 5) ? "0:/sys/meltingplot/" : "0:/macros/"
  var list = var.stale[iterations]
  while iterations < #var.list
    if fileexists(var.dir ^ var.list[iterations])
      M472 P{var.dir ^ var.list[iterations]}
      M118 P0 S{"deleted stale " ^ var.dir ^ var.list[iterations]}
