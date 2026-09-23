; Global variables for MeltingPlot system
;
; Grouped by SAFETY RELEVANCE first, by topic second. The tier a variable sits in says
; what a wrong value costs, so that anyone editing a default here - or assigning one in
; global-override.g - sees immediately what is at stake:
;
;   TIER 1  safety critical. Feeds the CE door interlock, the operating-mode switch, the
;           heater limits, the stall watchdog or an M112 path. A wrong value can injure
;           the operator or wreck the machine. Every default here must fail SAFE - doors
;           open, state unsafe, machine hot - never the convenient value. Its flags are
;           bit-flip hardened (see there): no bools, two int patterns, type-safe reads.
;   TIER 2  process integrity. A wrong value ruins a print, mis-calibrates or pauses a
;           job; nothing becomes dangerous. Defaults are the neutral "nothing known yet".
;   TIER 3  cosmetic and diagnostic. LED bookkeeping, debug output, cycle timing, the
;           cross-macro error channel.
;
; Moving a variable between tiers is a change of its meaning - move the declaration with
; it, so the file keeps telling the truth about what is safety relevant.
;
; The order of declarations is not free:
;   - a declaration must precede every use of it (idle_heater_cutoff_done sizes itself
;     from idle_heater_timeout, so it has to follow it)
;   - a value persisted in a file is loaded directly after its declaration
;   - arrays indexed by tool/axis/heater are sized explicitly, because globals load
;     before tools, axes and heaters exist
;   - global-override.g is loaded last: it may only assign, so everything it may touch
;     has to be declared by then


; move the machine-owned files of a pre-3.7 configuration into sys/overrides/ and
; sys/generated/ before anything below reads them (idempotent, see the macro;
; dsf-config.g calls it too)
M98 P"0:/sys/meltingplot/migrate.g"

; ==============================================================================
; TIER 1 - SAFETY CRITICAL
; ==============================================================================

; --- bit-flip hardened states -------------------------------------------------
; No flag in this tier is a bool. A bool is a single bit away from its opposite, so one
; flipped RAM bit (no ECC on the Duet) turns "door open" into "door closed" without any
; trace. Every flag is stored as one of two int patterns of maximal Hamming distance:
;   0x55555555 = 0101 0101 ... 0101  <-> true     renders as "1431655765"
;   0xAAAAAAAA = 1010 1010 ... 1010  <-> false    renders as "2863311530"
; All 32 bits differ, so no single, double or triple bit flip can turn one valid pattern
; into the other - a corrupted value is never a valid state. Verified on the machine
; (2026-09-13): RRF parses 0xAAAAAAAA as uint32 (2863311530, not as a negative int32),
; a global holds it type-stable, and comparisons against the int32 0x55555555 work.
;
; WRITING: assign the hex literal.  set global.door_left_open = 0xAAAAAAAA
; There is deliberately no named constant for the patterns - a constant would itself be
; a single global that a bit flip breaks for every consumer at once.
;
; READING: always through the string coercion "" ^ and against the rendered decimal:
;   ("" ^ global.door_left_open) == "2863311530"            "door closed"   (permissive)
;   ("" ^ global.potential_unsafe_state) != "2863311530"    "unsafe"        (restrictive)
;   ("" ^ global.door_left_switch_checked) == "1431655765"  "edge seen"     (permissive)
; The coercion is what keeps the CHECK itself alive: a direct comparison such as
; global.x != 0xAAAAAAAA throws "expected numeric operand" the moment x is not a number
; (verified on the machine with set global.x = true), and an expression error aborts the
; file that evaluates it - in daemon.g that is the safety loop. "" ^ x turns any type
; into a string (RRF meta-command reference, "Literals"), so a bool, null, float or a
; flipped type tag is just one more string that matches neither pattern.
; The rule is about the PERMISSIVE branch: it is reachable only by exact equality with
; the permissive pattern; the restrictive branch is the inequality, so every corrupted
; value lands there. Which pattern is permissive is stated at each declaration:
;   permissive 0xAAAAAAAA (false): door_left_open, door_right_open,
;                                  potential_unsafe_state, machine_is_hot,
;                                  idle_heater_pause_hold[]
;   permissive 0x55555555 (true):  door_left_switch_checked, door_right_switch_checked,
;                                  sensorless_z_homing, closed_loop_homing,
;                                  idle_heater_cutoff_done[], z_motor_stalled[]
; Never a bare "if global.x", never "== true"/"== false", never a numeric comparison
; against a pattern. Strings in this tier (machine_mode, saved_*_heater_state*) are read
; the same way, ("" ^ global.machine_mode) != "automatic", for the same reason.
;
; CONFIRMING: the patterns protect the VALUE, they do not protect the DECISION. A branch
; body can also run because the flow that led to it was wrong - a mis-evaluated condition,
; an EMI blip on the sensor the condition read, or the flag changing right after it was
; read. So every branch entered because a Tier-1 flag (or a door sensor) read PERMISSIVE
; re-reads it as its first statement, with the inverse comparison, and takes the
; restrictive path when the two disagree:
;   if ("" ^ global.door_left_open) == "2863311530"            ; gate: closed
;     if ("" ^ global.door_left_open) != "2863311530"          ; confirm: still closed?
;       <restrictive>
; The confirm re-evaluates, it does not reuse the first result - so it catches a wrongly
; taken branch whatever the source. For a GLOBAL the second read is also a genuinely new
; value: nothing caches it, and a write from another channel between the two reads is
; seen. For an OM field such as sensors.gpIn[] the second read is a second lookup, but in
; SBC mode how much the underlying model refreshed in between is not documented - so a
; sensor confirm is reliable against corrupted flow and only opportunistic against EMI
; (trigger4.g is the deliberate EMI double-check on the trigger path).
; Two rules keep the redundancy from becoming a hole itself:
;   - it may only ever move the outcome toward the RESTRICTIVE side. Never confirm a
;     restrictive branch - a downgrade, a heater cutoff, a halt - into a permissive one,
;     or the second read becomes a way to skip the safe action. The one documented
;     exception is trigger4.g, which re-reads the door SENSORS (not a flag) before the
;     downgrade to reject EMI, and where the daemon still performs the downgrade anyway.
;   - a disagreement is reported (M118 P0) and resolved restrictively, NOT halted. It is
;     not provably corruption: an operator can open a door in the window between the two
;     reads, and that legitimate race must not fire M112. Only a value that is neither
;     pattern is provable corruption, and that is what the DETECTION below halts on.
; Guard-style consumers (if ("" ^ global.machine_mode) != "automatic" -> abort) have their
; permissive branch in the fall-through, so their confirm is the same guard written a
; second time, with its own message - that is what catches the guard being skipped.
;
; DETECTION: daemon.g halts (M112) when a flag that persists between iterations holds
; neither pattern - the door states, the switch_checked flags, and machine_mode holding
; neither of its two strings - because nothing but the daemon or the two operating-mode
; scripts ever writes them: such a value means RAM, or an operator, is not to be trusted.
; potential_unsafe_state and machine_is_hot are recomputed from scratch every iteration
; and need no persistence check. Numeric values cannot be pattern-encoded (they are
; compared with < and >); they are bounded by plausibility instead, see each of them.
; In DWC the flags show as 1431655765 (true) and 2863311530 (false).

; --- CE operating mode --------------------------------------------------------
; "default" is the restricted mode of the CE declaration (keepout zone, 60 mm/min,
; reduced motor currents, every heater capped at 50 °C); "automatic" releases full
; speeds, currents and temperatures. Only daemon.g switches it, and only through
; ce-declaration/operating-mode/{default,automatic}.g - never assign it elsewhere, so any
; value other than the two strings is corruption and daemon.g halts on it.
; The upgrade requires both doors closed AND both door switches verified.
; Read rule: whoever GATES a permissive action tests for "automatic" (either
; == "automatic", or != "automatic" -> abort); whoever PERFORMS the downgrade (trigger4.g,
; the daemon's elif) tests != "default", so a corrupted string still downgrades.
global machine_mode = "default"              ; boots restricted, the daemon upgrades

; --- door interlock -----------------------------------------------------------
; Both doors are assumed OPEN at boot: the daemon's first iteration reads the switches
; and clears the flags, so a broken or unread switch can never look like a closed door.
; *_switch_checked is the proof that a real open->close edge was seen for that door and
; is the gate for automatic mode. daemon.g mirrors it in a script-local var, because a
; global can be set by hand in DWC to fake automatic mode - a mismatch clears both.
; Clearing the checked flags while machine_mode is still "automatic" and
; potential_unsafe_state is set fires M112: see "the mode-downgrade window" in CLAUDE.md
; before appending anything to the tail of print/finish.g.
global door_left_open = 0x55555555           ; 0x55555555 open, 0xAAAAAAAA closed (permissive)
global door_right_open = 0x55555555
global door_left_switch_checked = 0xAAAAAAAA ; 0x55555555 edge seen (permissive), 0xAAAAAAAA not
global door_right_switch_checked = 0xAAAAAAAA
; one-cycle edge markers, set by daemon.g on every open/close change. Nothing outside
; the daemon consumes them today (the door triggers run off the pins via M581) - they
; are the observable edge for anything that needs it. Plain bools: a flip has no effect.
global door_left_state_transition = false
global door_right_state_transition = false
; (door_ignore_trigger was removed 2026-09: print/prepare.g set it but nothing ever read it -
; the door triggers run off the pins via M581)

; --- unsafe-state detection (daemon motion tracker) ---------------------------
; potential_unsafe_state is true while anything moved within the last 0.25 s. It is what
; makes a mode downgrade with motion in progress an emergency stop, so it is recomputed
; from scratch at the top of every daemon iteration and must never be latched elsewhere.
; It flags any EXACT change of a reported position, physical motion or not: M92, G92,
; G10 L2/L20, T, M290, G29/M375 and M579 perturb these values by a rounding epsilon and
; therefore count as motion (CLAUDE.md, "the mode-downgrade window").
; Defaults to unsafe so a machine whose daemon has not run yet is never treated as safe.
global potential_unsafe_state = 0x55555555   ; 0x55555555 unsafe, 0xAAAAAAAA safe (permissive)
; tracker state, one entry per axis (X, Y, Z, U) / per extruder. Sized explicitly.
; Numeric, so not pattern-encoded. A flipped motion_*_pos element differs from the OM on
; the next iteration, reads as motion and is overwritten (restrictive, self-healing). A
; motion_*_time element flipped into the future reads as "inside the window"
; (restrictive); daemon.g reports and re-dates it. A flip into the past is not detectable
; and can only shorten the 0.25 s grace window of that one axis - residual risk.
global motion_axis_pos = vector(4,0)
global motion_axis_time = vector(4,0.0)
global motion_extruder_pos = vector(2,0)
global motion_extruder_time = vector(2,0.0)
; per-axis / per-extruder delta of the last observed move (0 = standstill). Written by
; the daemon only - exported for diagnostics, not read back by it. A flip has no effect.
global motion_axis_delta = vector(4,0)
global motion_extruder_delta = vector(2,0)

; --- hot surfaces and heater safety -------------------------------------------
; machine_is_hot drives the red warning LED whenever the machine is not in automatic
; mode. Defaults to hot so the warning is on until the daemon has actually measured
; bed, hotend and chamber below 50 °C.
global machine_is_hot = 0x55555555           ; 0x55555555 hot, 0xAAAAAAAA cold (permissive)

; idle heater cutoff - fire prevention for a machine left heated. Per-heater, indexed by
; heater number: heater 0 = bed by definition, heaters 1..#tools = tool heaters (heater h
; ↔ tool h-1), further heaters may follow. Sized explicitly because globals load before
; heaters exist.
; idle_heater_timeout: daemon.g caps the effective value at 7200 s, so a flipped high bit
; cannot disable the cutoff; raise the cap in daemon.g if a longer timeout is ever wanted.
; idle_since: upTime is monotonic, a value above state.upTime is impossible - daemon.g
; warns and treats it as timed out.
global idle_heater_timeout = {3600, 1800}                                   ; cutoff timeout (s): [0]=bed 60min, [1]=hotend 30min, effective max 7200
global idle_heater_pause_hold = {0x55555555, 0xAAAAAAAA}                    ; 0x55555555 keep on while paused with a job loaded (permissive; bed: preserve adhesion for resume), 0xAAAAAAAA cut off
global idle_heater_cutoff_done = vector(#global.idle_heater_timeout, 0xAAAAAAAA)  ; per-heater edge flag: 0x55555555 cutoff done (permissive: skip), 0xAAAAAAAA not; cleared on re-enable/activity
global idle_since = 0                                                        ; state.upTime of last detected activity (0 = boot)

; heater states saved by trigger4.g when a door opens and restored by trigger3.g when it
; closes again - the door interlock turns the heaters off, these remember what to bring
; back. "off" is the safe default: a restore that runs without a preceding save leaves
; everything off instead of switching an unattended heater on. trigger3.g restores only
; "active"/"standby" and warns about any other value (corrupted or an OM state such as
; "fault"), leaving that heater off. Sized 2 like the other tool-indexed arrays.
global saved_bed_heater_state = "off"                    ; bed heater state before door open
global saved_tool_heater_states = vector(2, "off")       ; per-tool heater state before door open

; --- stall and driver watchdog ------------------------------------------------
; Z homing runs the four Z motors into their stops; driver-stall.g counts the stalls and
; arms z_motor_stall_deadline. If not all four report within
; z_motor_stall_time_max seconds, daemon.g halts the machine with M112 - a Z axis that
; keeps driving against a jammed leadscrew destroys the gantry.
; z_motor_stall_deadline is numeric: armed, it must lie within [upTime, upTime + 30] - past
; means the motors did not report, further ahead means it changed without driver-stall.g
; writing it; daemon.g halts on both. z_motor_stall_time_max is accepted in 1..30 by
; driver-stall.g, anything else arms 5 s with a warning.
global z_motor_stalled = vector(4, 0xAAAAAAAA)       ; per Z motor: 0x55555555 stalled (permissive: counts towards "all reported"), 0xAAAAAAAA not
global z_motor_stall_deadline = 0                    ; state.upTime deadline (0 = no homing in progress)
global z_motor_stall_time_max = 5                    ; seconds all four Z motors have to report their stall

; stall/driver-error suppression flags. They switch the machine's reaction to a stall
; off, so they must always be cleared again on every exit path of the macro that set
; them - a flag left set silently disables the watchdog for the rest of the session.
; Suppression is the permissive state: only the exact true pattern suppresses.
global sensorless_z_homing = 0xAAAAAAAA  ; 0x55555555 expected Z stalls (z-axis/align-motors.g / z-axis/set-new-height.g), 0xAAAAAAAA a Z stall is an E-stop
global closed_loop_homing = 0xAAAAAAAA   ; 0x55555555 driver-error.g tolerates closed-loop errors (homex/homey/homeu), 0xAAAAAAAA pause
; (ignore_stall_events was removed 2026-09: nothing ever read it)


; ==============================================================================
; TIER 2 - PROCESS INTEGRITY
; ==============================================================================

; --- installed nozzle ---------------------------------------------------------
; The machine-state values in this and the following sections (nozzle, filament
; diameter, spool, build plate) describe what is physically installed. They share one persistence pattern: declared
; here with a "nothing known yet" default, then overwritten by a machine-local file in
; sys/generated/ that a confirm macro (hardware/confirm-*.g, spool/confirm.g) writes on
; change and this file runs on boot
; (fileexists-guarded). Those files are written on the machine, never shipped with the
; repo (.gitignore), and sys/generated/ is a directory neither the DWC config plugin
; nor the image ever writes to, so a config update keeps them. Nothing in there is
; meant to be edited by hand - the operator's own files live in sys/overrides/. Each
; holds only "set global.<name>... = <value>" lines.
; nozzle diameter - a property of the tool, not of the filament, so it is stored per
; tool and persisted (a nozzle change must survive a power cycle): tool 0 reads
; sys/generated/nozzle0.g, tool 1 nozzle1.g, both written by macro set-nozzle-diameter.
; The diameter also builds file names, paired with the filament diameter as the key
; "<filament>-<nozzle>" (filaments/<name>/nozzle-2.85-0.40.g, config-auto-pa-2.85-0.40.g)
; - always through filament-profile/calibration-key.g (writers) / filament-profile/find-calibration-file.g (readers, with
; the fallback to older nozzle-only and unsuffixed files).
; NEVER concatenate the raw value for that: RRF keeps the decimal places the value was
; written with, so 0.4 renders "0.4" but 0.4000 renders "0.4000" and anything computed
; renders "0.4000000" - each a different, silently wrong file name. Always derive the key
; as two decimal places of fixed width, via lib/format-number.g (which returns in global.result,
; so read it straight after the call):
;   M98 P"0:/sys/meltingplot/lib/format-number.g" F{global.nozzle_diameter[<tool>]} D2 W0
;   -> "0.40", "1.20"
; Sized explicitly because globals load before tools exist.
global nozzle_diameter = vector(2, 0.6)
if fileexists("0:/sys/generated/nozzle0.g")
  M98 P"0:/sys/generated/nozzle0.g"
if fileexists("0:/sys/generated/nozzle1.g")
  M98 P"0:/sys/generated/nozzle1.g"
; nozzle type - what the nozzle is made of and whether it is a high-flow (CHT) design.
; A key string, one of: "brass", "cht" (brass CHT), "hardened" (hardened steel, rated
; for abrasive filaments), "cht-hardened", "tungsten-carbide", "copper" (plated copper),
; "other", "unknown" (nothing recorded yet). The key is never used in a file name.
; Same persistence as the diameter: sys/generated/nozzle-type<tool>.g, written by
; hardware/confirm-nozzle-type.g (macro set-nozzle-diameter asks for both on a nozzle change).
global nozzle_type = vector(2, "unknown")
if fileexists("0:/sys/generated/nozzle-type0.g")
  M98 P"0:/sys/generated/nozzle-type0.g"
if fileexists("0:/sys/generated/nozzle-type1.g")
  M98 P"0:/sys/generated/nozzle-type1.g"

; --- filament diameter --------------------------------------------------------
; diameter of the filament each tool is built for (mm). A property of the tool like the
; nozzle: config.g applies it (M200 D / M404 N) and the consumption tracker turns
; extruded millimetres into grams with it. Machine-local: macro set-filament-diameter
; (hardware/confirm-filament-diameter.g) persists a change in sys/generated/filament-diameter<tool>.g
; and re-applies M200 at once, so a change survives a power cycle.
global filament_diameter = vector(2, 2.85)
if fileexists("0:/sys/generated/filament-diameter0.g")
  M98 P"0:/sys/generated/filament-diameter0.g"
if fileexists("0:/sys/generated/filament-diameter1.g")
  M98 P"0:/sys/generated/filament-diameter1.g"

; --- mounted spool ------------------------------------------------------------
; Spool catalog: the spool bodies the spool prompt (spool/confirm.g) offers, each a
; name and the weight of the empty spool in grams (tare). The tare belongs to the spool
; body, not to the material or the net weight - two 2.3 kg spools of different make
; weigh differently when empty - so it is one machine-wide list, not a per-profile
; value. A flat list of pairs - spool type i has its name at 2i and its tare at 2i+1 -
; because that is what fileread() returns. Declared here with the default list; a
; machine replaces it with its own list in sys/overrides/spool-catalog.csv (one CSV line,
; written by macro edit-spool-catalog or edited in DWC, never overwritten by a config
; update), which spool/read-catalog.g reads on use - deliberately NOT at boot, so an edit
; applies at once and a broken file can never break globals. At most 20 spool types
; (fileread returns at most 40 elements per call on RRF 3.6).
global spool_catalog = {"Pappe",500,"PC",350,"PE",450}
; The spool on each tool: nominal net filament weight in grams (int, 0 = unknown), what
; is left on it in grams (float), the empty-spool weight in grams (tare, int, 0 =
; unknown - taken from the spool catalog, lets the operator enter the scale reading),
; and the density (g/cm3) of the filament it carries - a copy of the profile's value,
; taken at load time, so the tracker never depends on which profile ran last. All four
; are written together to sys/generated/spool<tool>.g
; by spool/store.g (the spool stays on the machine across a power cycle). Asked at the
; feed prompt of every filament load (spool/confirm.g, cancelling keeps the values)
; and by macro set-spool-size.
; Consumption: spool/track.g books the print's slicer-commanded extrusion
; (move.extruders[].rawPosition - reset by RRF at every print start, unaffected by G92,
; not counting macro extrusion such as purges, NET of G1 retractions so it can run
; backwards by a few mm) onto spool_remaining, scaled by the M221 extrusion factor:
; grams = mm * pi * (d/2)^2 * density / 1000, signed deltas. daemon.g calls it every
; 60 s while printing (no file write), print/finish.g flushes it and persists (W1). The job
; is bracketed by the firmware hooks, never guessed from the counter or a file name:
; print/prepare.g arms spool_track_active and zeroes the baseline (RRF zeroed rawPosition
; with the job), the W1 flush books, persists and disarms - so print/finish.g may run any
; number of times after a job, every call but the first is a no-op. A spool with density
; 0 is not tracked. spool_track_baseline is the last booked rawPosition per tool,
; spool_track_time the daemon's sample timestamp - all session state, not persisted.
global spool_net_weight = vector(2, 0)
global spool_remaining = vector(2, 0.0)
global spool_tare = vector(2, 0)
global spool_density = vector(2, 0.0)
if fileexists("0:/sys/generated/spool0.g")
  M98 P"0:/sys/generated/spool0.g"
if fileexists("0:/sys/generated/spool1.g")
  M98 P"0:/sys/generated/spool1.g"
global spool_track_baseline = vector(2, 0.0)
global spool_track_time = 0
global spool_track_active = false        ; armed by print/prepare.g (job started, baseline 0), disarmed by the print/finish.g flush - the bracket that makes print/finish.g idempotent

; --- build plate --------------------------------------------------------------
; surface of the installed build plate. A key string, one of: "pei" (smooth PEI),
; "pei-textured", "pertinax" (Hartpapier / phenolic paper), "g10" (Glasfaser / FR4
; fiberglass), "carbon" (carbon fibre plate), "glass", "other", "unknown". Machine-wide,
; set by macro set-bed-surface (hardware/confirm-bed-surface.g), persisted in
; sys/generated/bed-surface.g. Not used in a file name.
global bed_surface = "unknown"
if fileexists("0:/sys/generated/bed-surface.g")
  M98 P"0:/sys/generated/bed-surface.g"

; --- filament: material parameters --------------------------------------------
global filament_max_flow_rate = 20
; nozzle temperature (C) the last filament was unloaded at - written by filament/unload-procedure.g,
; used by filament/load-procedure.g to detect high-temp residue in the nozzle.
; persisted to a file because the residue survives a power cycle.
global last_filament_temp = 0
if fileexists("0:/sys/generated/last-filament-temp.g")
  M98 P"0:/sys/generated/last-filament-temp.g"
; per-profile temperatures, set by filaments/<name>/temps.g (executed by
; filament/on-load.g and on-unload.g when called with F"<name>"). temps.g is the
; canonical per-material temperature store: load.g/unload.g are machine-generated
; boilerplate and M98's R parameter is the pause flag (NOT passed to the macro),
; so temperatures can neither live in nor be passed into those files.
global filament_temp_active = 0              ; extrusion/load temperature
global filament_temp_standby = 0             ; standby temperature
global filament_temp_unload = 0              ; unload temperature (0 = same as active)
; per-profile material data, set by filaments/<name>/material.g (user-editable, written
; by filament-profile/create-material-file.g - offered at the filament-load prompt, by macros
; create-filament-profile and repair-filament-profile). Run by spool/confirm.g,
; which resets density and sizes first so a profile without material.g never inherits
; the previous material's values. 0 = unknown.
; A material may come on several spool sizes (net filament weight in grams). Empty
; (vector(0, ...)) = unknown; material.g writes {1000,2500,} - the trailing comma keeps a
; one-element list an array in RRF 3.5/3.6 syntax. The empty-spool weight is not a
; material value, it comes from the spool catalog (global.spool_catalog above).
; Both are a transfer channel, not state: material.g writes them, spool/confirm.g
; takes them into locals right after running it and stores the density per tool in
; spool_density[tool]. Shared by both tools - never read them anywhere else (IDEX: two
; different materials in T0 and T1, possibly in two motion systems at once).
global material_density = 0.0                ; g/cm3 - turns extruded mm into grams
global material_spool_weights = vector(0, 0) ; g net filament per usual spool size

; --- filament: load/unload state ----------------------------------------------
global filament_load_failed = false
; per-tool deferred physical load, armed by filament/on-load.g (from load.g), consumed by
; filament/on-config.g (from the machine-generated config.g).
; Sized explicitly because globals load before tools exist.
global filament_load_pending = vector(2, false)
; legacy shim: load.g files generated before 2026-07 still set this flag. Nothing
; consumes it anymore (the watchdog flags such profiles for repair), but it must
; exist so an old load.g does not hard-error with "unknown variable".
global deferred_filament_load_t0 = false
; filament-profile watchdog (daemon.g): a DWC-created profile missing the standard
; M98 lines fails silently - M701 registers the filament in the OM but nothing is
; ever physically loaded. Detection is behavioral (fileread cannot parse G-code).
global filament_load_dispatched = ""         ; filament whose physical load was dispatched by filament/on-config.g ("" = none)
global filament_unload_done = false          ; set by filament/unload-procedure.g; checked by daemon.g on the OM name -> "" transition
global filament_unload_skip = false          ; daemon-initiated M702: one-shot, skip the physical unload; self-cleared by filament/on-unload.g and unload-procedure.g
global filament_broken_profile = ""          ; profile name captured by the watchdog before the forced unload (for the repair macro)

; --- MFM: speed backoff -------------------------------------------------------
global mfm_backoff_level = 3              ; 3 = full speed; every P4/P5 error sets M220 to 20 % * level and steps down, 0 = no step left
global mfm_ignore_events = false          ; filament-error.g ignores MFM events (swing suppression, calibration macros)
global mfm_backoff_time = 0               ; upTime of the last backoff step or speed restore - daemon.g restores 30 s after it

; --- MFM: false positive detection --------------------------------------------
global mfm_prev_percentage = null         ; previous lastPercentage reading
global mfm_swing_count = 0                ; large-swing count in current window
global mfm_swing_window_start = 0         ; window start time (upTime)
global mfm_suppress_until = 0             ; upTime until which to suppress (0 = not active)
global mfm_sample_time = 0.0              ; last MFM check timestamp (sub-second precision)

; --- MFM: persistent error tracking (survives swing suppressions and fast-track resets)
global mfm_error_start_pos = null         ; extruder position at first error in sequence (null = no active tracking)
global mfm_normal_since = 0               ; upTime when sustained normal readings began
global mfm_recovery_resume_time = 0       ; upTime of last auto-recovery pass + auto-resume (0 = none); loop breaker in filament-error.g
global mfm_recovery_requested = false     ; armed by filament-error.g right before its M25, consumed by pause.g (runs the recovery before the pause commits)
global mfm_recovery_result = -1           ; verdict of the recovery run by pause.g: -1 = did not run, 0 = false positive, 1+ = real issue

; --- MFM: systematic flow-bias (e-steps) --------------------------------------
; DETECT in daemon.g (non-blocking); APPLY only at standstill in filament-error.g when
; the next MFM error pauses the print - M92 blocks, forbidden in daemon.g.
global mfm_esteps_detected = false        ; one-shot detection guard for this print, reset in print/finish.g
global mfm_esteps_sample_time = 0         ; last flow-bias sample timestamp (upTime)
global mfm_esteps_drift_since = 0         ; upTime when the current settle window started (0 = inside deadband/no drift)
global mfm_esteps_drift_avg = 0           ; avgPercentage at the start of the settle window (flatness reference)
global mfm_esteps_suggested = 0           ; bounded (±5%) target steps/mm computed by the detector (0 = none pending)
global mfm_esteps_baseline = 0.0          ; e-steps captured before the correction was applied (0 = not applied; for print/finish.g restore)

; --- MFM: heater PWM tracking for extrusion verification ----------------------
global mfm_pwm_min = 0.0                  ; min avgPwm in current window
global mfm_pwm_max = 0.0                  ; max avgPwm in current window
global mfm_pwm_range = 0.0                ; computed range from last complete window
global mfm_pwm_window_start = 0           ; PWM window start time

; --- pause / resume re-prime bookkeeping --------------------------------------
; pause_extruder is the extruder drive of the tool active at pause (-1 = paused without
; tool), pause_extruder_pos its position counter (move.extruders[].position accumulates
; every commanded move, is not reset by G92 or pause/resume - only at print start) at the
; end of pause.g, re-taken at the end of filament/mfm-recovery.g so the recovery's own
; test/purge extrusion doesn't count as manual.
; pause_extruder_peak is the melt-zone "full" mark: the position at which the nozzle is
; primed again (snapshot + 12.7), raised by daemon.g to the highest position reached
; while paused. Forward extrusion beyond the mark is purge that leaves the nozzle, so
; the net delta since the snapshot says nothing about the melt zone - only retraction
; after the peak does. resume.g re-primes exactly peak - position (clamped to 0..12.7).
global pause_extruder = -1
global pause_extruder_pos = 0.0
global pause_extruder_peak = 0.0

; --- scanning Z probe ---------------------------------------------------------
global szp_touch_z_offset = -0.1        ; M558.3 H param — assumed nozzle Z (mm) at touch detection (less negative = closer to bed)
global szp_warm_threshold = 40           ; temperature (°C) above which warm calibration is used for scanning Z-probe


; ==============================================================================
; TIER 3 - COSMETIC AND DIAGNOSTIC
; ==============================================================================

; activate debug messages
global debug = false

; result variable for macros - cross-macro error propagation (0 = success) and the return
; channel of macros that produce a value (lib/format-number.g). Only valid IMMEDIATELY after the
; call that set it: no macro saves or restores it, so capture it into a local var on the
; very next line.
global result = 0

; led colors. led_color caches the code of the colour currently shown, so
; lib/set-led-color.g can skip a redundant update. led_colors translates that code into
; its name: led_colors[led_color] is the name lib/set-led-color.g takes in C"..." (it
; takes the code in I as well). 5 and 6 are the full and the dim phase of pulse_white.
; Nothing reads the table - it is the lookup for whoever sees led_color in DWC.
global led_color = 0
global led_colors = {"white", "blue", "green", "yellow", "red", "pulse_white", "pulse_white"}

; daemon bookkeeping
global daemon_cycle_time = 0            ; duration (s) of the last daemon iteration
global daemon_reload = false            ; set to true to make daemon.g leave its loop and be reopened


; ==============================================================================
; MACHINE VARIANT CONFIGURATION - declaration of physical presence
; ==============================================================================
; Optional hardware is selected by a boolean: present or not. It is never reconfigured -
; pin assignment is identical on every machine (CE documentation) and stays in config.g.
; The defaults below describe a machine WITHOUT the optional part; a machine that has it
; sets the flag in global-override.g. Declaration and default always stay here so that
; every variable exists on every machine and consumers never need exists() guards.
; Not a tier of its own: these describe the machine rather than its state. Mind that
; has_exhaust_fan does carry a safety dimension - left false on a machine that has the
; fan, fume extraction never runs.
global has_aux_fan = false              ; auxiliary part cooling fan on out2, slicer P2
global has_exhaust_fan = false          ; exhaust / chamber fan on out1, slicer P3

; Per-machine overrides. Values only - anything that needs G-code (drive directions,
; sensor wiring, ...) belongs in machine-override instead. The file lives in
; sys/overrides/, which no config update overwrites, so the local edits survive. It may
; only assign (set global.<name> = ...), so a typo fails loudly at boot instead of
; silently doing nothing. The fileexists guard keeps a machine bootable that lost it.
if fileexists("0:/sys/overrides/global-override.g")
  M98 P"0:/sys/overrides/global-override.g"
