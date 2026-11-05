; self-test/check-door.g
; Monthly check, one door: an open door must show on its switch and take the machine out of
; automatic mode (trigger4.g, daemon.g), and closing it must bring automatic mode back.
;   M98 P"0:/sys/meltingplot/self-test/check-door.g" I<gpIn> S"<door>"
; I: sensors.gpIn index (2 left, 3 right; 0 open, 1 closed). S: the door's name, German, inflected.
; Findings go into global.self_test_found. Expects automatic mode; only macro
; maintenance/monthly-check calls this.

;; {% if state.messageBox %}{{ state.messageBox.message }}{% endif %}
M291 R"Tür öffnen" P{"Öffnen Sie die " ^ param.S ^ " Tür und bestätigen Sie dann. Die Maschine muss dabei die Betriebsart Automatik verlassen."} S2

; default.g takes a moment, and the operator may confirm right after opening
while ("" ^ global.machine_mode) == "automatic" && sensors.gpIn[param.I].value == 0 && iterations < 25
  G4 P200

if sensors.gpIn[param.I].value != 0
  set global.self_test_found = global.self_test_found ^ "Türschalter " ^ param.S ^ " Tür meldet nicht offen; "
elif ("" ^ global.machine_mode) == "automatic"
  set global.self_test_found = global.self_test_found ^ param.S ^ " Tür offen, aber Betriebsart Automatik; "

;; {% if state.messageBox %}{{ state.messageBox.message }}{% endif %}
M291 R"Tür schließen" P{"Schließen Sie die " ^ param.S ^ " Tür wieder und bestätigen Sie dann."} S2

M98 P"0:/sys/meltingplot/ce-declaration/operating-mode/wait-automatic.g"
if global.result != 0
  set global.self_test_found = global.self_test_found ^ param.S ^ " Tür zu, aber keine Betriebsart Automatik; "
