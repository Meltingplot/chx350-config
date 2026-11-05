; Emergency stop test of the monthly check (CLAUDE.md, "Power-on self-test"): record that this
; trigger fired, only while that test is armed. A real emergency stop costs this one condition.
; Nothing in front of M112 may end this file. This line cannot throw (exists() and the "" ^
; coercion: an expression error would end the file), and a failed write ends only the macro it
; calls (DSF MacroFile.Abort), so M112 follows either way and the test counts as not done.
if exists(global.self_test_estop_state) && (("" ^ global.self_test_estop_state) == "1" || ("" ^ global.self_test_estop_state) == "3")
  M98 P"0:/sys/meltingplot/self-test/estop-fired.g"
M98 P"0:/sys/meltingplot/lib/set-led-color.g" C"yellow"
M112 ; emergency shutdown

; THIS FILE CONTAINS CE RELEVANT CONFIGURATIONS, ANY CHANGES TO THIS FILE MAY RESULT IN A LOST OF THE CE DECLARATION