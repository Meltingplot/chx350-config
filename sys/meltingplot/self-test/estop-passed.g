; self-test/estop-passed.g
; trigger2.g recorded that the emergency stop fired (self_test_estop_state 4), so the monthly check
; has passed. Called by self-test/check-estop.g at the next boot, and by macro
; maintenance/monthly-check when config.g ended before it reached that file. Each tells the operator
; itself.

set global.self_test_estop_state = 0
set global.self_test_done[2] = global.operating_time_base + state.upTime
set global.self_test_failed[2] = ""
M98 P"0:/sys/meltingplot/self-test/store.g"
M118 P0 L2 S{"Self-test: monthly check passed, the emergency stop fired (" ^ floor(global.self_test_done[2] / 3600) ^ " h)"}
