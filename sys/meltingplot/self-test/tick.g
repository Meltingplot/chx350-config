; self-test/tick.g
; Dispatcher of the power-on self-test (CLAUDE.md, "Power-on self-test"), called by the machine
; tick (trigger8.g) once state.upTime has reached global.self_test_wake: every 60 s while
; nothing runs, every tick (10 s) while a check runs. It starts what is due, in hours of
; operation (operating_time_base + upTime), and only on an idle machine, so a job or a macro
; always comes first: a check that runs when the machine stops being idle is dropped and tried
; again later. A flow (macro maintenance/self-test) asks for one tier in self_test_manual and
; waits for it, which makes the machine "busy", so that one tier may also run while busy.
; Runs on the Trigger channel, where trigger4.g waits behind it: nothing in here may block.
; One if/elif chain, no M99 (lib/set-led-color.g says why).

var now = global.operating_time_base + state.upTime
var free = state.status == "idle" || (state.status == "busy" && global.self_test_manual >= 0)
set global.self_test_wake = state.upTime + 60

if global.self_test_run >= 0
  if state.upTime - global.self_test_since > 300
    ; No tier takes this long (weekly: at most 240 s + two ticks), so a macro error ended it and
    ; it would re-enter for ever, starving the other tiers. A check that cannot run has not passed.
    var stuck = global.self_test_run
    M118 P0 L1 S{"Error: self-test: tier " ^ var.stuck ^ " did not finish - see the macro error in the log"}
    set global.self_test_failed[var.stuck] = "Selbsttest nicht durchgelaufen; "
    set global.self_test_retry[var.stuck] = state.upTime + 1800
    set global.self_test_run = -1
    set global.self_test_found = ""
    set global.self_test_manual = -1
    if var.stuck == 1
      M98 P"0:/sys/meltingplot/self-test/check-weekly.g" A1
    set global.self_test_step = 0
  elif !var.free
    if global.self_test_run == 1
      M98 P"0:/sys/meltingplot/self-test/check-weekly.g" A1
    else
      M118 P0 L2 S"Self-test: quick check dropped - the machine is no longer idle"
      set global.self_test_retry[0] = state.upTime + 300
      set global.self_test_found = ""
      set global.self_test_run = -1
      set global.self_test_step = 0
      set global.self_test_manual = -1
  elif global.self_test_run == 0
    M98 P"0:/sys/meltingplot/self-test/check-quick.g"
  else
    M98 P"0:/sys/meltingplot/self-test/check-weekly.g"
elif var.free
  ; The emergency stop test of a monthly check, decided after the reset. 4: trigger2.g recorded
  ; that it fired. Still armed: it never fired. A power failure, an M999 or switching off after a
  ; dead button all look like that, so the tier stays due, and a defect from before stays too.
  if global.self_test_estop_state == 4
    set global.self_test_estop_state = 0
    set global.self_test_done[2] = var.now
    set global.self_test_failed[2] = ""
    M98 P"0:/sys/meltingplot/self-test/store.g"
    M118 P0 L2 S{"Self-test: monthly check passed, the emergency stop fired (" ^ floor(var.now / 3600) ^ " h)"}
    M291 R"Monatsprüfung bestanden" P"Die Monatsprüfung ist bestanden: Der NOT-HALT hat ausgelöst." S1 T60
  elif global.self_test_estop_state == 1 || global.self_test_estop_state == 3
    set global.self_test_estop_state = (global.self_test_estop_state == 3) ? 2 : 0
    M98 P"0:/sys/meltingplot/self-test/store.g"
    M118 P0 L1 S"Warning: self-test: the machine restarted during the emergency stop test, but it did not fire - the monthly check stays due"
    M291 R"NOT-HALT nicht geprüft" P"Die Maschine hat während der NOT-HALT-Prüfung neu gestartet, ohne dass er ausgelöst hat. Die Monatsprüfung bleibt fällig." S1 T60

  ; 0 in the interval switches a tier off; a tier that never ran is due at once. A pass in the
  ; future means the hour meter lost its file: due as well, it does not wait for the hours to catch up.
  var due = vector(3, false)
  while iterations < 3
    var age = var.now - global.self_test_done[iterations]
    set var.due[iterations] = global.self_test_interval[iterations] > 0 && state.upTime >= global.self_test_retry[iterations] && (global.self_test_done[iterations] < 0 || var.age < 0 || var.age / 3600 >= global.self_test_interval[iterations])

  var tier = global.self_test_manual
  if var.tier < 0
    set var.tier = var.due[0] ? 0 : (var.due[1] ? 1 : -1)
  if var.tier >= 0
    ; found may hold what a monthly check left behind when it was cancelled
    set global.self_test_found = ""
    set global.self_test_since = state.upTime
    set global.self_test_run = var.tier
    if var.tier == 0
      M98 P"0:/sys/meltingplot/self-test/check-quick.g"
    else
      M98 P"0:/sys/meltingplot/self-test/check-weekly.g"
  elif var.due[2] && !global.self_test_notified
    ; needs an operator: only tell, once per boot. The flow's tile shows on the start page.
    set global.self_test_notified = true
    M118 P0 L2 S{"Self-test: the monthly check is due (" ^ floor(var.now / 3600) ^ " h) - macro maintenance/monthly-check"}
    M291 R"Monatsprüfung fällig" P"Die Monatsprüfung ist fällig: Kachel Monatsprüfung auf der Startseite. Etwa 15 Minuten, mit dem Bediener an der Maschine." S1 T60

; next tick while a check runs
if global.self_test_run >= 0
  set global.self_test_wake = 0
