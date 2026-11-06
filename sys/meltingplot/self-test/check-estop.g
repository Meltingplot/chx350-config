; self-test/check-estop.g
; Decides the emergency stop test of a monthly check, once, at the boot: config.g calls this right
; after it started the event log. The operator has the result as soon as the machine is back. In
; the machine tick it came a minute or more later, and until then the tile still showed the check
; as due, which looked like a failed test (seen on the machine, 2026-11-06).
; 4: trigger2.g recorded that it fired, the check has passed. Still armed (1, or 3 with a defect from
; before): it never fired. A power failure, an M999 or switching off after a dead button all look
; like that, so the tier stays due, and a defect from before stays too.
; T120: config.g takes about 25 s, and the UI has to reconnect before it can show the box.

if global.self_test_estop_state == 4
  M98 P"0:/sys/meltingplot/self-test/estop-passed.g"
  M291 R"NOT-HALT hat ausgelöst" P"Die Monatsprüfung ist bestanden: Der NOT-HALT hat ausgelöst." S1 T120
elif global.self_test_estop_state == 1 || global.self_test_estop_state == 3
  set global.self_test_estop_state = (global.self_test_estop_state == 3) ? 2 : 0
  M98 P"0:/sys/meltingplot/self-test/store.g"
  M118 P0 L1 S"Warning: self-test: the machine restarted during the emergency stop test, but it did not fire - the monthly check stays due"
  M291 R"NOT-HALT nicht geprüft" P"Die Maschine hat während der NOT-HALT-Prüfung neu gestartet, ohne dass er ausgelöst hat. Die Monatsprüfung bleibt fällig." S1 T120
