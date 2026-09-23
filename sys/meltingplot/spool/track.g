; spool/track.g
; Books the filament every tool's extruder has fed since the last call onto its spool:
; global.spool_remaining[T] -= grams. Source is move.extruders[E].position, the extruder
; motor position in mm (RRF Move.cpp: LiveMachineCoordinate) - everything the motor did:
; print moves and retractions, and all extrusion inside macros (load, purge, prime,
; e-steps, NLE and PA calibration, MFM recovery) and from the console or DWC. The M221
; factor is already applied, G92 E does not touch it (it only sets the virtual position).
; rawPosition, the earlier source, counts none of the macro extrusion (GCodes.cpp: only
; moves with !IsDoingFileMacro()) and nothing outside a job would have been booked.
;   grams = mm * pi * (filament_diameter / 2)^2 * density / 1000
; Booked with its sign: an unload pulls filament back towards the spool and books it
; back (capped at the spool's net weight), a sample taken mid-retraction is corrected by
; the next one.
; RRF zeroes the position at every job start (GCodes.cpp StartPrinting, right before
; start.g) - that jump is not a retraction. start.g re-bases the baseline to 0 before
; anything extrudes; a jump to exactly 0 is also taken as that reset here (re-based, not
; booked), which covers the moment before start.g and a power-fail resume, which does
; not run start.g. The one misread - a real move that ends on exactly 0.000 mm - drops
; that move, well under a gram.
; The baseline is advanced before the booking, so two calls running at the same time
; (daemon.g and print/finish.g) can double-book only between two consecutive lines.
; A tool whose spool has density 0 (no material.g, nothing entered) is skipped but its
; baseline still follows, so entering a density later never books history.
;   M98 P"0:/sys/meltingplot/spool/track.g"     - book only: OM reads and set, no file
;                                                 write (daemon.g: every 60 s while
;                                                 printing, at every extruder stop otherwise)
;   M98 P"0:/sys/meltingplot/spool/track.g" W1  - book and write spool<tool>.g (daemon.g
;                                                 while not printing, at most once a minute)
;   M98 P"0:/sys/meltingplot/spool/track.g" J1  - job end (print/finish.g): book, write,
;                                                 and report what is left, once per job
; print/finish.g runs twice at a normal job end (end G-code, then stop.g): both calls
; book and write, the second finds nothing new; only the first reports - start.g arms
; global.spool_report_pending, the report clears it.

if global.debug
  echo "spool/track.g"

var job = exists(param.J) && param.J == 1
var write = var.job || (exists(param.W) && param.W == 1)
var report = var.job && global.spool_report_pending
if var.report
  set global.spool_report_pending = false

while iterations < min(#tools, 2)
  if tools[iterations] != null
    var pos = move.extruders[tools[iterations].extruders[0]].position
    var mm = var.pos - global.spool_track_baseline[iterations]
    set global.spool_track_baseline[iterations] = var.pos
    ; mm != 0: the extruder moved; pos != 0: not the job-start reset
    if var.mm != 0 && var.pos != 0 && global.spool_density[iterations] > 0
      var grams = {var.mm * pi * pow(global.filament_diameter[iterations] / 2, 2) * global.spool_density[iterations] / 1000}
      set global.spool_remaining[iterations] = max(0.0, global.spool_remaining[iterations] - var.grams)
      if global.spool_net_weight[iterations] > 0 && global.spool_remaining[iterations] > global.spool_net_weight[iterations]
        set global.spool_remaining[iterations] = global.spool_net_weight[iterations]   ; a booked-back unload cannot overfill the spool
    if var.write
      M98 P"0:/sys/meltingplot/spool/store.g" T{iterations}
    if var.report && global.spool_density[iterations] > 0
      M118 P0 S{"Spool on tool " ^ iterations ^ ": " ^ floor(global.spool_remaining[iterations]) ^ " g of " ^ global.spool_net_weight[iterations] ^ " g left"}
