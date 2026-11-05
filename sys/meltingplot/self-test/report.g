; self-test/report.g
; Ends a run of an automatic self-test tier and takes over what it found in
; global.self_test_found:
;   M98 P"0:/sys/meltingplot/self-test/report.g" T<0 quick, 1 weekly>
; Passed: the tier counts as done now. Failed: it stays due and runs again after 30 min, also to
; notice a repair. start.g refuses jobs while self_test_failed[] holds the list. The box comes only
; when a tier that was fine fails: the findings carry readings, so the text changes with every
; retry, and a T0 box never times out, they would stack up and hold every later box back. The
; console and the event log get every new text. A flow that asked for the run shows the result
; itself, so no box then. The fixed sentence comes first: M291 cuts P off at 256 bytes.
; Called on the Trigger channel: nothing in here may block.

var tier = param.T
var hours = floor((global.operating_time_base + state.upTime) / 3600)
var name = (var.tier == 0) ? "quick" : "weekly"

if global.self_test_found == ""
  set global.self_test_done[var.tier] = global.operating_time_base + state.upTime
  if var.tier > 0
    M98 P"0:/sys/meltingplot/self-test/store.g"
  M118 P0 L2 S{"Self-test: " ^ var.name ^ " check passed (" ^ var.hours ^ " h)"}
else
  set global.self_test_retry[var.tier] = state.upTime + 1800
  if global.self_test_found != global.self_test_failed[var.tier]
    M118 P0 L1 S{"Error: self-test: " ^ var.name ^ " check failed (" ^ var.hours ^ " h): " ^ global.self_test_found}
  if global.self_test_failed[var.tier] == "" && global.self_test_manual < 0
    M291 R"Selbsttest fehlgeschlagen" P{(global.self_test_block_jobs ? "Kein neuer Druck, bis er wieder besteht. " : "") ^ global.self_test_found} S1 T0

set global.self_test_failed[var.tier] = global.self_test_found
set global.self_test_found = ""
set global.self_test_run = -1
set global.self_test_step = 0
set global.self_test_manual = -1
