; migrate_overrides.g
; Moves the machine-owned files from their pre-3.7 location (sys/meltingplot/) into
; the two directories a config update never overwrites: the operator-edited overrides
; into sys/overrides/, the files the machine writes itself into sys/generated/. Run at
; boot from dsf-config.g and from globals, before either reads any of them. Idempotent:
; once nothing is left at the old location it costs a few fileexists lookups and
; nothing else, so the two calls may overlap. Remove once every machine runs 3.7.
;
; D1: a file found at the old location is by definition the machine's own copy - the
; operator's edited override or a value the machine wrote - so it replaces whatever the
; update shipped at the new location (the commented-out template). A machine-written
; file never exists at both places, because nothing writes the new one before this ran.
; M471 does not create the target directory (DSF: File.Move), so sys/generated/ - which
; nothing ships - is created first; M470 on an existing directory is a no-op on DSF.
;
; Two lists, because one would exceed the 255-character limit of a meta-command argument.
var shipped = {"global-override.g", "machine-override", "dsf-config-override.g", "printer-name.g"}
var written = {"nozzle0.g", "nozzle1.g", "nozzle-type0.g", "nozzle-type1.g", "filament-diameter0.g", "filament-diameter1.g", "spool0.g", "spool1.g", "bed-surface.g", "last-filament-temp.g"}

while iterations < #var.shipped
  if fileexists("0:/sys/meltingplot/" ^ var.shipped[iterations])
    M471 S{"0:/sys/meltingplot/" ^ var.shipped[iterations]} T{"0:/sys/overrides/" ^ var.shipped[iterations]} D1
    M118 P0 S{"moved sys/meltingplot/" ^ var.shipped[iterations] ^ " to sys/overrides/"}

while iterations < #var.written
  if fileexists("0:/sys/meltingplot/" ^ var.written[iterations])
    M470 P"0:/sys/generated"
    M471 S{"0:/sys/meltingplot/" ^ var.written[iterations]} T{"0:/sys/generated/" ^ var.written[iterations]} D1
    M118 P0 S{"moved sys/meltingplot/" ^ var.written[iterations] ^ " to sys/generated/"}
