; self-test/report.g
; Ends a run of the quick or the weekly tier and takes over what it found in global.self_test_found:
;   M98 P"0:/sys/meltingplot/self-test/report.g" T<0 quick, 1 weekly>
; Passed: the tier counts as done now. Failed: it stays due and runs again after 30 min, also to
; notice a repair. start.g refuses jobs while self_test_failed[] holds the list. The flow reports the
; outcome itself. The event log gets every new text, the findings carry readings, so it changes with
; every retry.

var tier = param.T
var hours = floor((global.operating_time_base + state.upTime) / 3600)
var name = (var.tier == 0) ? "quick" : "weekly"

; the tier's last step, it stays up to its hour otherwise (CLAUDE.md, "Progress"). M292 acknowledges
; the head of the queue, whatever that is: only a non-blocking box with a timeout, as this step is,
; never a notice the operator has not read yet (T0, start.g, daemon.g) or someone else's prompt.
if state.messageBox != null
  if state.messageBox.mode < 2 && state.messageBox.timeout != 0
    M292

set global.self_test_due[var.tier] = false
if global.self_test_found == ""
  set global.self_test_done[var.tier] = global.operating_time_base + state.upTime
  if var.tier > 0
    M98 P"0:/sys/meltingplot/self-test/store.g"
  M118 P0 L2 S{"Self-test: " ^ var.name ^ " check passed (" ^ var.hours ^ " h)"}
else
  set global.self_test_retry[var.tier] = state.upTime + 1800
  if global.self_test_found != global.self_test_failed[var.tier]
    M118 P0 L1 S{"Error: self-test: " ^ var.name ^ " check failed (" ^ var.hours ^ " h): " ^ global.self_test_found}

set global.self_test_failed[var.tier] = global.self_test_found
set global.self_test_found = ""
