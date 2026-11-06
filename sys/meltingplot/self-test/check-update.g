; self-test/check-update.g
; Is an update under way? Hands the answer back in global.self_test_update_running, valid on the
; caller's next line only. Called by self-test/tick.g and the flows maintenance/self-test and
; maintenance/monthly-check, reads and set only.
; Update and self-test take turns (CLAUDE.md, "Power-on self-test"). This is the test's half: no tier
; starts while one of these holds. The update's half: mp-dsf-firmware flashes only after 10 s of idle,
; so it waits for a test that already runs. Three signs:
; - global.ota_pending_until, an upTime deadline the image writes (rpi-image-gen): mp-dsf-firmware in
;   every poll of a tryboot boot, mp-ota-gate while the connector installs. It runs out if its writer
;   dies, and a reset clears it. The image's "OTA Update" box is no such sign: it only informs, any
;   other box at the head of the queue hides it, and an M292 removes it.
; - The status reads "updating": a board is being flashed.
; - A board reads flashing or resetting: between two boards the status reads idle for a moment, and
;   a board swapped for one with other firmware is flashed on an ordinary boot, without the deadline.
;   Not timedOut or flashFailed: those are defects, which the quick tier has to report.

set global.self_test_update_running = state.status == "updating" || state.upTime < global.ota_pending_until
; boards[0] is the main board, which has no state (Platform.cpp)
while iterations < #boards
  if iterations > 0
    if boards[iterations].state == "flashing" || boards[iterations].state == "resetting"
      set global.self_test_update_running = true
