; spool/store.g
; Persists the spool state of one tool - global.spool_net_weight[T], spool_remaining[T],
; spool_tare[T] and spool_density[T] - to sys/generated/spool<T>.g, which sys/meltingplot/globals.g runs
; on every boot (the spool stays on the machine across a power cycle). Writes the file
; from the globals, so every caller sets the globals first and then calls this:
;   M98 P"0:/sys/meltingplot/spool/store.g" T0
; Callers: spool/confirm.g (operator entered a spool) and spool/track.g W1 (flush at
; print end). Never call it from daemon.g - the daemon must not write files.
; The file is machine-local state: written on the machine, never shipped with the repo,
; and a config update must not overwrite it.

if global.debug
  echo "spool/store.g"

; the tool index is built as a string explicitly so that no float formatting can leak into
; the file name or into the array index of the generated assignments
var tool = (exists(param.T) && param.T == 1) ? 1 : 0
var idx = var.tool == 1 ? "1" : "0"
var file = "0:/sys/generated/spool" ^ var.idx ^ ".g"
echo >{var.file} "; spool on tool " ^ var.idx ^ " - written by spool/store.g, do not edit (macro set-spool-size)"
echo >>{var.file} "set global.spool_net_weight[" ^ var.idx ^ "] = " ^ global.spool_net_weight[var.tool]
echo >>{var.file} "set global.spool_remaining[" ^ var.idx ^ "] = " ^ global.spool_remaining[var.tool]
echo >>{var.file} "set global.spool_tare[" ^ var.idx ^ "] = " ^ global.spool_tare[var.tool]
echo >>{var.file} "set global.spool_density[" ^ var.idx ^ "] = " ^ global.spool_density[var.tool]
