; ce-declaration/operating-mode/wait-automatic.g
; Waits until the machine is back in automatic mode: both door switches verified and both
; doors closed (doors/ensure-checked-closed.g, which prompts the operator), then up to 5 s
; for daemon.g to run the upgrade (operating-mode/automatic.g). For a macro that sends the
; operator into the build chamber and heats or moves again afterwards: the open door
; dropped the machine to default mode (trigger4.g - heaters off and capped at 50 C,
; keepout zone), and nothing may heat or move before the upgrade has run.
;   M98 P"0:/sys/meltingplot/ce-declaration/operating-mode/wait-automatic.g"
; Hands back 0 in global.result once automatic mode is confirmed, 1 when it is not reached -
; valid on the caller's very next line only. machine_mode is bit-flip hardened (see
; globals): "automatic" only by exact match, and the permissive exit is read twice.

if global.debug
  echo "ce-declaration/operating-mode/wait-automatic.g"

M98 P"0:/sys/meltingplot/ce-declaration/doors/ensure-checked-closed.g"
set global.result = 1                 ; after the door check - wait-closed.g resets global.result to 0

while ("" ^ global.machine_mode) != "automatic" && iterations < 10
  G4 P500                             ; daemon.g upgrades within one cycle of the doors closing
if ("" ^ global.machine_mode) != "automatic"
  M118 P0 S"Warning: automatic mode not reached after the doors were closed"
  M99
; confirm the permissive exit (globals, "CONFIRMING")
if ("" ^ global.machine_mode) != "automatic"
  M118 P0 S"Warning: automatic mode not confirmed on re-read"
  M99

M400                                  ; dsf specific
G4 P500                               ; dsf specific - wait for the keepout zone to be removed, as print/prepare.g
set global.result = 0
