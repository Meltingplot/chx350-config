; self-test/tick.g
; Scheduler of the self-test (CLAUDE.md, "Power-on self-test"), called by the machine tick
; (trigger8.g) once state.upTime has reached global.self_test_wake, every 60 s. It works out which
; tier is due, in hours of operation (operating_time_base + upTime), and whether one can run now.
; It runs no test: they are the ordinary flow maintenance/self-test, on a channel of their own. On
; the Trigger channel a wait would hold up trigger2.g and trigger4.g. So it starts the flow on HTTP,
; as if DWC had started it: M98.3 returns once the macro is queued. A1 tells the flow that nobody
; asked for it, so it must not wait for an answer.
; Reads and set, M98.3, M118 and M291 S1 only: nothing in here may block.

var now = global.operating_time_base + state.upTime
var wanted_before = global.self_test_wanted
set global.self_test_wake = state.upTime + 60

; An update comes first: nothing is planned, started or announced while it runs. The flow would stand
; in its way, and any new box cuts the update's notice to 1 s. What is due stays due. The machine has
; to be tested after an update, so the quick tier comes right after it, whatever its last result was,
; and mp-dsf-firmware waits for that outcome before its closing message.
M98 P"0:/sys/meltingplot/self-test/check-update.g"
if global.self_test_update_running
  set global.self_test_wanted = false
  set global.self_test_done[0] = -1
  set global.self_test_retry[0] = 0
  set global.self_test_quick_outcome = 0
  M99

M98 P"0:/sys/meltingplot/self-test/check-due.g"

; Only the quick tier starts by itself, and only on an idle machine: it reads and neither heats nor
; moves. The weekly tier heats, so it comes with the next job (start.g) or by hand, and the monthly
; check only by hand (Tim, 2026-11-06).
set global.self_test_wanted = state.status == "idle" && global.self_test_due[0]

; Result 1: HTTP is busy, nothing was queued, the next look tries again. Anything worse (the channel
; disabled, the file missing) would repeat its error every minute, so it stops until the next boot.
; Not behind a notice the operator must close (T0, it has no timeout): the steps would queue unseen
; behind it, and the retries of a failed tier would fill the queue of 8 boxes, at which RRF drops the
; oldest non-blocking box, that notice (MessageBox::Create). The flow waits until it is closed.
if global.self_test_wanted && global.self_test_can_start
  var notice = false
  if state.messageBox != null
    set var.notice = state.messageBox.timeout == 0
  if var.notice
    if global.self_test_quick_outcome == 0
      set global.self_test_quick_outcome = 3
  else
    M98.3 P"0:/macros/meltingplot/maintenance/self-test" A1
    if result > 1
      set global.self_test_can_start = false
      M118 P0 L1 S"Warning: self-test: the flow could not be started - it does not start by itself until the next boot"

; So that mp-dsf-firmware does not wait for a quick tier that cannot come. It is not final: a tier
; that runs later still writes its outcome (self-test/report.g).
if global.self_test_quick_outcome == 0 && (global.self_test_interval[0] <= 0 || !global.self_test_can_start)
  set global.self_test_quick_outcome = 3

; Needs an operator: only tell, once per boot. Not in the minute the flow is about to start, whose
; first step would replace the box at once. Still wanted a minute later, nothing is starting it.
; The flow's tile shows on the start page.
if state.status == "idle" && global.self_test_due[2] && !global.self_test_notified && (!global.self_test_wanted || var.wanted_before)
  set global.self_test_notified = true
  M118 P0 L2 S{"Self-test: the monthly check is due (" ^ floor(var.now / 3600) ^ " h) - macro maintenance/monthly-check"}
  M291 R"Monatsprüfung fällig" P"Die Monatsprüfung ist fällig: Kachel Monatsprüfung auf der Startseite. Etwa 15 Minuten, mit dem Bediener an der Maschine." S1 T60
