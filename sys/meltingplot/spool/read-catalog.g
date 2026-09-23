; spool/read-catalog.g
; Loads the machine's spool catalog into global.spool_catalog from
; sys/overrides/spool-catalog.csv when that file exists; without it the default list
; declared in globals stays.
;   M98 P"0:/sys/meltingplot/spool/read-catalog.g"
; Callers: spool/confirm.g (before the spool-body prompt) and macro
; edit-spool-catalog. The file is read on use, not at boot, so an edit in DWC applies at
; once and a broken file can only affect those two, never globals.
; File format: ONE line of comma-separated pairs "<name>",<weight of the empty spool
; in grams>, e.g.
;   "Pappe",500,"PC",350,"PE",450
; read with fileread() (RRF 3.5+, see the Duet meta-command reference): names in double
; quotes (a quote inside a name is written twice), weights as plain numbers, no comment
; line - anything else aborts the command that reads it. The line may be as long as it
; needs to be; there is no 255-character limit on it. Verified on the machine
; 2026-09-23: that example line reads back as {Pappe,500,PC,350,PE,450}.
; fileread returns at most 40 elements per call (MaxFileReadArrayElements in RRF
; Configuration.h) and RRF 3.6 cannot concatenate arrays (3.7 can), so the catalog
; holds at most 20 spool types; a longer file is cut to 20 with a warning. An empty
; field reads as null (a stray trailing comma, a missing weight) and is replaced here
; by "" or 0, so no consumer ever sees null.

if global.debug
  echo "spool/read-catalog.g"

var file = "0:/sys/overrides/spool-catalog.csv"
if !fileexists(var.file)
  M99
set global.spool_catalog = fileread(var.file, 0, 40, ',')
if #fileread(var.file, 40, 1, ',') > 0
  M118 P0 S"Warning: sys/overrides/spool-catalog.csv holds more than 20 spool types - only the first 20 are offered"
while iterations < #global.spool_catalog
  if global.spool_catalog[iterations] == null
    set global.spool_catalog[iterations] = (mod(iterations, 2) == 0) ? "" : 0
