; spool_track.g
; Books the filament the current print has extruded since the last call onto the spool
; of every tool: global.spool_remaining[T] -= grams. Source is
; move.extruders[E].rawPosition, the slicer-commanded extrusion of the running job
; (RRF GCodes.cpp: rawExtruderTotalByDrive += extrusionAmount - zeroed at every print
; start, not touched by G92, extrusion inside macros - purges, load/unload - is not
; counted, and it is NET: a G1 E-5 retraction subtracts, so the value runs backwards by
; the retraction length and comes back on the un-retract; firmware retraction G10/G11
; is not counted at all), scaled by the M221 extrusion factor (move.extruders[E].factor)
; to what the extruder actually fed:
;   grams = mm * pi * (filament_diameter / 2)^2 * density / 1000
; The delta is booked with its sign, so a sample taken while retracted is corrected by
; the next one and the sum stays exact. The job is never inferred from the counter (a
; decrease is what a retraction looks like) nor from job.file.fileName (gone before
; cancel.g runs, and the same file twice in a row would be indistinguishable) but
; bracketed by the firmware hooks: print_start (start.g, once per job start) arms
; global.spool_track_active and zeroes the baseline - RRF zeroed rawPosition with the
; job - and the W1 flush books, persists and disarms. Disarmed, this macro does nothing
; at all, which is what lets print_end run any number of times after a job (end-gcode,
; stop.g, cancel.g, the operator): every call but the first is a no-op. rawPosition
; keeps the job's total until the next start, so without the bracket a second flush
; would book the whole job again.
; A tool whose spool has density 0 (no material.g, nothing entered) is skipped but its
; baseline still follows, so entering a density later never books history.
;   M98 P"0:/sys/meltingplot/spool_track.g"      - book only (daemon.g, every 60 s)
;   M98 P"0:/sys/meltingplot/spool_track.g" W1   - book, persist (store_spool.g), report
; Without W1 this is OM reads and set only - non-blocking, no file write - which is what
; lets daemon.g call it. W1 writes files and belongs to print_end.

if global.debug
  echo "spool_track.g"

; not armed: no job is being tracked (never started through print_start, or already
; flushed) - nothing to book, and a repeated print_end must not book the job twice
if !global.spool_track_active
  M99

var persist = exists(param.W) && param.W == 1

while iterations < min(#tools, 2)
  if tools[iterations] != null
    var e = tools[iterations].extruders[0]
    var raw = move.extruders[var.e].rawPosition
    if var.raw != global.spool_track_raw[iterations]
      if global.spool_density[iterations] > 0
        ; signed: a sample taken mid-retraction books a few mm back, the next one re-books them
        var mm = {(var.raw - global.spool_track_raw[iterations]) * move.extruders[var.e].factor}
        var grams = {var.mm * pi * pow(global.filament_diameter[iterations] / 2, 2) * global.spool_density[iterations] / 1000}
        set global.spool_remaining[iterations] = max(0.0, global.spool_remaining[iterations] - var.grams)
        if global.spool_size[iterations] > 0 && global.spool_remaining[iterations] > global.spool_size[iterations]
          set global.spool_remaining[iterations] = global.spool_size[iterations]   ; a booked-back retraction cannot overfill the spool
      set global.spool_track_raw[iterations] = var.raw
    if var.persist
      M98 P"0:/sys/meltingplot/store_spool.g" T{iterations}
      set global.spool_track_raw[iterations] = 0.0        ; print over - RRF zeroes rawPosition at the next start
      if global.spool_density[iterations] > 0
        M118 P0 S{"Spool on tool " ^ iterations ^ ": " ^ floor(global.spool_remaining[iterations]) ^ " g of " ^ global.spool_size[iterations] ^ " g left"}

; flushed - disarm, so that every further print_end of this job books nothing
if var.persist
  set global.spool_track_active = false
