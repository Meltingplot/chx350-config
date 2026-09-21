; Tier-1 flags are bit-flip hardened and read through the "" ^ coercion (see globals):
; "door closed" only by exact match with "2863311530" (0xAAAAAAAA), "switch checked" only
; by exact match with "1431655765" (0x55555555) - anything else takes the default branch
if ("" ^ global.door_left_open) == "2863311530" && ("" ^ global.door_right_open) == "2863311530" && ("" ^ global.door_left_switch_checked) == "1431655765" && ("" ^ global.door_right_switch_checked) == "1431655765"
  ; Confirm the gate with the inverse comparison before releasing the machine (globals,
  ; "CONFIRMING") - the four reads above decided this, four fresh reads have to agree.
  ; Disagreement falls through to the same default.g as a plain "not allowed": restrictive,
  ; and the daemon upgrades on a later iteration once the flags are stable.
  if ("" ^ global.door_left_open) != "2863311530" || ("" ^ global.door_right_open) != "2863311530" || ("" ^ global.door_left_switch_checked) != "1431655765" || ("" ^ global.door_right_switch_checked) != "1431655765"
    M118 P0 S"Warning: door interlock not confirmed on re-read - reloading default mode"
    M98 P"0:/sys/meltingplot/ce-declaration/operating-mode/default.g"
  else
    M98 P"0:/sys/meltingplot/ce-declaration/operating-mode/automatic.g"
else
  M98 P"0:/sys/meltingplot/ce-declaration/operating-mode/default.g"
