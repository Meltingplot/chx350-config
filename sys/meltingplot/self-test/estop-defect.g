; self-test/estop-defect.g
; The operator says the emergency stop did nothing: from now on start.g refuses every job, also
; after a reboot, whatever the self-test's switches say, until trigger2.g records it firing in a
; monthly check. Only macro maintenance/monthly-check calls this.

set global.self_test_estop_state = 2
M98 P"0:/sys/meltingplot/self-test/store.g"
set global.self_test_failed[2] = "NOT-HALT hat nicht ausgelöst; "
M118 P0 L1 S"Error: self-test: the emergency stop did not halt the machine"

;; > Der NOT-HALT hat nicht ausgelöst.
;;
;; Die Maschine darf so nicht betrieben werden. Sie startet keinen Druck mehr, bis diese Prüfung
;; bestanden ist. Lassen Sie den NOT-HALT instandsetzen.
M291 R"NOT-HALT defekt" P"Der NOT-HALT hat nicht ausgelöst. Die Maschine darf so nicht betrieben werden und startet keinen Druck mehr, bis diese Prüfung bestanden ist." S2
echo "Error: the emergency stop did not halt the machine"
