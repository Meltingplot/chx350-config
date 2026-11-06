; self-test/weekly-before-job.g
; A due weekly tier goes in front of the job (Tim, 2026-11-06): it blocks the job, establishes its own
; conditions, shows its flow, and the job starts after it. Called by start.g as its last step: the door
; check has run, so both doors are closed, and start.g has worked out self_test_due[].
; Hands back in global.result, valid on the caller's next line only: 0 the job may start, 1 it must
; not, and the operator has been told why.
; No prompt: nobody has to answer, the operator may have walked away after starting the job. An open
; door ends it and the job. It is the one way out here: while start.g runs an M25 is deferred until
; the macro ends (GCodes2.cpp), and the UI offers M0 only for a paused job.

set global.result = 0
if !global.self_test_due[1] || global.self_test_failed[0] != ""
  M99
M98 P"0:/sys/meltingplot/self-test/check-update.g"
if global.self_test_update_running
  M99

; Everything off that check-weekly-ready.g asks for. "off" first, as in the monthly check: trigger3.g
; must not bring a heater back when automatic mode returns. A setpoint the test could not give back
; under default mode's 50 C cap goes to 0, the job sets its own temperature anyway.
while iterations < #tools
  if tools[iterations] != null
    if #tools[iterations].heaters > 0
      set global.saved_tool_heater_states[iterations] = "off"
      M568 P{iterations} A0
      if tools[iterations].active[0] >= heat.heaters[iterations + 1].max
        M568 P{iterations} S0 A0
set global.saved_bed_heater_state = "off"
M140 P0 S-273.15
while iterations < #global.fan_adjustable
  M106 P{global.fan_adjustable[iterations]} S0

var refuse = ""
M98 P"0:/sys/meltingplot/self-test/check-weekly-ready.g"
if !global.self_test_weekly_ready
  ;; Der Wochentest ist fällig und läuft vor diesem Druck. Dafür kühlt die Maschine ab, Heizungen und
  ;; Bauteillüfter sind aus. Danach läuft der Test, und der Druck startet von selbst.
  ;;
  ;; Öffnen Sie eine Tür, bricht das den Druckauftrag ab.
  ;;
  ;; {% for h in heat.heaters %}{% if h %}
  ;; - {{ "Bett" if loop.index0 == 0 else "Hotend" }}: **{{ h.current | round(1) }} °C**, Ziel unter {{ 40 if loop.index0 == 0 else 35 }} °C
  ;; {% endif %}{% endfor %}
  M291 R"Wochentest: Abkühlen" P"Der Wochentest läuft vor dem Druck. Die Maschine kühlt ab, danach startet alles von selbst. Tür öffnen bricht den Druckauftrag ab." S1 T7200

var start = state.upTime
while !global.self_test_weekly_ready
  if sensors.gpIn[2].value != 1 || sensors.gpIn[3].value != 1
    set var.refuse = "Tür geöffnet: Wochentest und Druckauftrag abgebrochen. Der Test läuft beim nächsten Start."
    break
  if state.upTime - var.start > 7200
    set var.refuse = "Nach 2 Stunden nicht bereit für den Wochentest: Heizungen aus, Bett unter 40 °C, Hotend unter 35 °C, Bauteillüfter aus."
    break
  G4 S5
  M98 P"0:/sys/meltingplot/self-test/check-weekly-ready.g"

if var.refuse == ""
  M98 P"0:/sys/meltingplot/self-test/check-weekly.g" J1
  if global.result != 0
    set var.refuse = "Wochentest abgebrochen: Tür oder Heizung haben übernommen. Der Test läuft beim nächsten Start."
  elif global.self_test_block_jobs && global.self_test_failed[1] != ""
    set var.refuse = "Wochentest nicht bestanden, kein neuer Druck (Makro maintenance/self-test): " ^ global.self_test_failed[1]

if var.refuse != ""
  M118 P0 L1 S"Error: self-test: the weekly check before the job did not pass - print job not started"
  M291 R"Druck nicht gestartet" P{var.refuse} S1 T60
  set global.result = 1
  M99

set global.result = 0
