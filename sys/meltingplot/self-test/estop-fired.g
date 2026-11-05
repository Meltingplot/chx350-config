; self-test/estop-fired.g
; Called by trigger2.g right before M112, only while the emergency stop test of the monthly check
; is armed: records that the trigger really fired. self-test/tick.g counts the tier as passed at
; the next boot. One appended line, the last assignment wins when globals.g runs the file. A failed
; write ends only this macro, M112 follows anyway, and the test then counts as not done: the safe
; direction. Nothing else belongs in here, the machine is waiting for its emergency stop.

echo >>"0:/sys/generated/self-test.g" "set global.self_test_estop_state = 4"
