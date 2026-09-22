; store_spool.g
; Persists the spool state of one tool - global.spool_size[T], spool_remaining[T],
; spool_tare[T] and spool_density[T] - to sys/meltingplot/spool<T>.g, which sys/meltingplot/globals runs
; on every boot (the spool stays on the machine across a power cycle). Writes the file
; from the globals, so every caller sets the globals first and then calls this:
;   M98 P"0:/sys/meltingplot/store_spool.g" T0
; Callers: confirm_spool_size.g (operator entered a spool) and spool_track.g W1 (flush at
; print end). Never call it from daemon.g - the daemon must not write files.
; The file is machine-local state: written on the machine, never shipped with the repo,
; and a config update must not overwrite it.

if global.debug
  echo "store_spool.g"

; the tool index is built as a string explicitly so that no float formatting can leak into
; the file name or into the array index of the generated assignments
var tool = (exists(param.T) && param.T == 1) ? 1 : 0
var idx = var.tool == 1 ? "1" : "0"
var file = "0:/sys/meltingplot/spool" ^ var.idx ^ ".g"
echo >{var.file} "; spool on tool " ^ var.idx ^ " - written by store_spool.g, do not edit (macro set-spool-size)"
echo >>{var.file} "set global.spool_size[" ^ var.idx ^ "] = " ^ global.spool_size[var.tool]
echo >>{var.file} "set global.spool_remaining[" ^ var.idx ^ "] = " ^ global.spool_remaining[var.tool]
echo >>{var.file} "set global.spool_tare[" ^ var.idx ^ "] = " ^ global.spool_tare[var.tool]
echo >>{var.file} "set global.spool_density[" ^ var.idx ^ "] = " ^ global.spool_density[var.tool]
