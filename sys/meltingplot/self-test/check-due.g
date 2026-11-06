; self-test/check-due.g
; Works out which tier is due, in hours of operation (operating_time_base + upTime), into
; global.self_test_due[]. Called by self-test/tick.g, and by start.g, which cannot wait for the tick's
; next look. Reads and set only.
; 0 in the interval switches a tier off; a tier that never ran is due at once. A pass in the future
; means the hour meter lost its file: due as well, it does not wait for the hours to catch up.

var now = global.operating_time_base + state.upTime
while iterations < 3
  var age = var.now - global.self_test_done[iterations]
  var hours = global.self_test_interval[iterations]
  set global.self_test_due[iterations] = var.hours > 0 && state.upTime >= global.self_test_retry[iterations] && (global.self_test_done[iterations] < 0 || var.age < 0 || var.age / 3600 >= var.hours)
