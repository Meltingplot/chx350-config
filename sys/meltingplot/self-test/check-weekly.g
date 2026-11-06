; self-test/check-weekly.g
; Weekly tier of the self-test (CLAUDE.md, "Power-on self-test"), every self_test_interval[1]
; hours of operation: does every heater heat, does every fan with a tacho turn? No motion and no
; operator, and the temperatures stay below the 50 C that default mode allows (operating-mode/
; default.g), so it may run before anyone checked the doors. Never started by the machine: part of the
; flow maintenance/self-test by hand, and of start.g with J1. Both have checked
; self-test/check-weekly-ready.g first. Up to 4 min.
; A door opening, a job (with J1: the end of the job it runs for) or someone else taking a heater over
; ends the run without a verdict, and it stays due: hands back 1 in global.result then, 0 otherwise,
; valid on the caller's next line only.
; Heater 0 = bed, heater h = tool h-1, as the idle cutoff in daemon.g. Only the tool's active setpoint
; changes and goes back afterwards (self-test/stop-heater.g), the standby one stays.

var count = #tools + 1
var start = state.upTime
var aborted = false
var for_job = exists(param.J)
var target = vector(var.count, 0)
var saved = vector(var.count, 0)
var finished = vector(var.count, false)
var at_target = vector(var.count, 0)

set global.self_test_found = ""
M118 P0 L2 S"Self-test: weekly check started"

while iterations < var.count
  if iterations == 0
    set var.target[0] = ceil(heat.heaters[0].current) + 4
    M140 P0 S{var.target[0]}
  else
    set var.saved[iterations] = tools[iterations - 1].active[0]
    set var.target[iterations] = 45
    M568 P{iterations - 1} S45 A2
while iterations < #global.fan_adjustable
  M106 P{global.fan_adjustable[iterations]} S1

;; Die Bauteillüfter laufen kurz mit voller Drehzahl. Nichts bewegt sich, die Maschine bleibt
;; unter 50 °C. Öffnen Sie eine Tür, bricht sie den Test ab.
;;
;; {% for f in fans %}{% if f and loop.index0 < 4 and f.rpm >= 0 %}
;; - {{ f.name }}: **{{ f.rpm }} U/min**
;; {% endif %}{% endfor %}
M291 R"Wochentest: Lüfter" P"Wochentest: Die Bauteillüfter laufen kurz mit voller Drehzahl. Nichts bewegt sich." S1 T3600
G4 S5

; Fans 0-3 follow the slicer's numbering, 4 and up are the water loop (below). Fan 1 turns with fan
; 0's PWM, fans without a tacho read -1. A thermostat that does not drive its fan (actualValue 0, fan
; 1 with the hotend below 10 C) says nothing about the fan.
while iterations < min(#fans, 4)
  if fans[iterations] != null
    if fans[iterations].rpm == 0 && fans[iterations].actualValue > 0
      set global.self_test_found = global.self_test_found ^ "Lüfter steht: " ^ fans[iterations].name ^ "; "
while iterations < #global.fan_adjustable
  M106 P{global.fan_adjustable[iterations]} S0

;; Hotend und Bett heizen zur Probe, bis zu 4 Minuten. Nichts bewegt sich, die Maschine bleibt
;; unter 50 °C. Öffnen Sie eine Tür, bricht sie den Test ab.
;;
;; {% for h in heat.heaters %}{% if h %}
;; - {{ "Bett" if loop.index0 == 0 else "Hotend" }}: **{{ h.current | round(1) }} °C** von {{ h.active }} °C
;; {% endif %}{% endfor %}
;; {% for f in fans %}{% if f and loop.index0 >= 4 %}
;; - {{ f.name }}: **{{ f.rpm }} U/min**
;; {% endif %}{% endfor %}
M291 R"Wochentest: Heizungen" P"Wochentest: Hotend und Bett heizen zur Probe, bis zu 4 Minuten. Nichts bewegt sich, unter 50 °C." S1 T3600

; Bed: 3 C rise in 240 s. Hotend: 44 C in 90 s, then 5 s longer, because above 40 C the thermostat
; has to start the radiators (config.g).
var running = true
while var.running && !var.aborted && iterations < 400
  G4 S1
  if sensors.gpIn[2].value != 1 || sensors.gpIn[3].value != 1 || (job.file.fileName != null) != var.for_job
    set var.aborted = true
  set var.running = false
  while iterations < var.count
    if !var.finished[iterations]
      var off = false
      if heat.heaters[iterations].state == "fault"
        set global.self_test_found = global.self_test_found ^ "Heizung " ^ iterations ^ ": Fehler beim Heizen; "
        set var.off = true
      elif heat.heaters[iterations].state != "active" || heat.heaters[iterations].active != var.target[iterations]
        set var.aborted = true
      elif var.at_target[iterations] > 0
        if state.upTime - var.at_target[iterations] >= 5
          ; the thermostat of the water loop's fans reads the hotend of tool 0 (config.g)
          if iterations == 1
            while iterations < #fans - 4
              if fans[iterations + 4] != null
                if fans[iterations + 4].rpm == 0
                  set global.self_test_found = global.self_test_found ^ "Lüfter steht: " ^ fans[iterations + 4].name ^ "; "
          set var.off = true
      elif heat.heaters[iterations].current >= var.target[iterations] - 1
        if iterations == 0
          set var.off = true
        else
          set var.at_target[iterations] = state.upTime
      elif state.upTime - var.start > ((iterations == 0) ? 240 : 90)
        set global.self_test_found = global.self_test_found ^ "Heizung " ^ iterations ^ ": " ^ heat.heaters[iterations].current ^ " C statt " ^ var.target[iterations] ^ " C nach " ^ (state.upTime - var.start) ^ " s; "
        set var.off = true
      if var.off
        set var.finished[iterations] = true
        M98 P"0:/sys/meltingplot/self-test/stop-heater.g" H{iterations} S{var.saved[iterations]}
      else
        set var.running = true

if var.aborted
  ; Only a heater still at this test's setpoint is this test's to switch off, and trigger3.g must
  ; not bring it back: a door that opened saved it as "active" (trigger4.g).
  while iterations < var.count
    if !var.finished[iterations] && heat.heaters[iterations].active == var.target[iterations]
      if iterations == 0
        set global.saved_bed_heater_state = "off"
      else
        set global.saved_tool_heater_states[iterations - 1] = "off"
      M98 P"0:/sys/meltingplot/self-test/stop-heater.g" H{iterations} S{var.saved[iterations]}
  M118 P0 L2 S"Self-test: weekly check ended early - door, heater or job took over, it stays due"
  ; for a job it stays due at once: a job does not start until the tier has run
  if !var.for_job
    set global.self_test_retry[1] = state.upTime + 300
  set global.self_test_due[1] = false
  set global.self_test_found = ""
  ; this run's step only, see report.g
  if state.messageBox != null
    if state.messageBox.mode < 2 && state.messageBox.timeout != 0
      M292
  set global.result = 1
else
  M98 P"0:/sys/meltingplot/self-test/report.g" T1
  set global.result = 0
