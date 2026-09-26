; lib/ask-tool.g
; Asks which tool a macro acts on and hands the tool number back in global.result, -1 when
; the operator cancelled or no tool has an extruder. A flow of the CHX 350 UI is started
; with a plain M98 and no parameters, so every macro that works on one tool asks here.
; The choice is built from the object model, never from a fixed T0/T1 list: every defined
; tool with an extruder, labelled with the material loaded on it ("T0 · PETG", "T1 · leer"),
; the current tool of the calling channel's motion system preselected. A single such
; tool - the CHX 350 today - is returned without a prompt.
;   M98 P"0:/sys/meltingplot/lib/ask-tool.g" S"<question>"
; S is the prompt text for classic DWC and PanelDue (the CHX 350 UI shows the ;; text
; below instead); without it a generic question is asked. global.result is only valid on
; the caller's very next line. Cancel is J2 (result = -1, execution continues): the caller
; decides what a cancel means, and it may run while a job is paused.

if global.debug
  echo "lib/ask-tool.g"

var labels = vector(0, "")
var numbers = vector(0, 0)
var preset = 0
while iterations < #tools
  if tools[iterations] != null
    if #tools[iterations].extruders > 0
      if iterations == state.currentTool
        set var.preset = #var.numbers
      var filament = move.extruders[tools[iterations].extruders[0]].filament
      set var.labels = var.labels ^ vector(1, "T" ^ iterations ^ " · " ^ ((var.filament == null || var.filament == "") ? "leer" : var.filament))
      set var.numbers = var.numbers ^ vector(1, iterations)

if #var.numbers == 0
  set global.result = -1
  M99
if #var.numbers == 1
  set global.result = var.numbers[0]
  M99

;; Wählen Sie den Druckkopf. Zu jedem steht das Material, das gerade geladen ist.
M291 R"Druckkopf wählen" P{exists(param.S) ? param.S : "Welcher Druckkopf?"} S4 K{var.labels} F{var.preset} J2
if result != 0             ; J2 leaves input undefined - result must be tested right here
  set global.result = -1
  M99
set global.result = var.numbers[input]
