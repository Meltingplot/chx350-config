; self-test/estop-fired.g
; Called by trigger2.g right before M112, only while the emergency stop test of the monthly check
; is armed: records that the trigger really fired. self-test/check-estop.g counts the tier as passed
; at the next boot. One appended line, the last assignment wins when globals.g runs the file. A failed
; write ends only this macro, M112 follows anyway, and the test then counts as not done: the safe
; direction. Nothing else belongs in here, the machine is waiting for its emergency stop.
; The flow never gets to a line of its own after the prompt, so its completion is sent from here,
; only after the write worked. The CHX 350 UI reports a flow as failed that ends without this
; output (flows/store.ts) and reads it from any channel. M118 P0, because an echo would only answer
; the Trigger channel.

echo >>"0:/sys/generated/self-test.g" "set global.self_test_estop_state = 4"
M118 P0 L0 S";; Completed"
