; self-test/store.g
; Persists when the self-test tiers last passed, in hours of operation, and the state of the
; emergency stop test to sys/generated/self-test.g, which sys/meltingplot/globals.g runs on every
; boot. Written from the globals, so every caller sets them first:
;   M98 P"0:/sys/meltingplot/self-test/store.g"
; The quick tier is not in the file: it runs after every boot anyway. An echo into a file never
; waits for motion, which lets the machine tick call this.
; The hour meter is written with it and first. It is otherwise saved only every 15 min, and a
; reboot right after a pass would put that pass in the future, which tick.g takes for a lost meter.

set global.operating_time_saved = state.upTime
echo >"0:/sys/generated/operating-time.g" "set global.operating_time_base = " ^ (global.operating_time_base + state.upTime)

var file = "0:/sys/generated/self-test.g"
echo >{var.file} "; self-test state - written by self-test/store.g, do not edit"
echo >>{var.file} "set global.self_test_done[1] = " ^ global.self_test_done[1]
echo >>{var.file} "set global.self_test_done[2] = " ^ global.self_test_done[2]
echo >>{var.file} "set global.self_test_estop_state = " ^ global.self_test_estop_state
