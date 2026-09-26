; filament-profile/store-index.g
; Adds a filament profile created on the machine to sys/generated/filament-profiles.csv,
; the machine's part of the profile list that filament-profile/read-index.g builds for
; macro change-filament, unless the name is listed already.
;   M98 P"0:/sys/meltingplot/filament-profile/store-index.g" S"<profile name>"
; Call it once the profile's temps.g exists: read-index.g lists only profiles that have
; one, so a name checked before would not be found and a shipped profile would be listed
; twice. Callers: macros create-filament-profile and repair-filament-profile, and the
; "Anderes Profil" choice of macro change-filament, which lists a profile created before
; this index existed once its name has been typed in.
; The file is one CSV line of quoted names that only grows: each name is appended with
; echo >>> (no newline), so fileread() always reads the whole list as the first line. A
; name with a double quote is not stored - it would have to be doubled, and RRF has no
; string replace; such a profile is still loaded through "Anderes Profil".

if global.debug
  echo "filament-profile/store-index.g"

if !exists(param.S)
  M99
if param.S == ""
  M99
if find(param.S, """") >= 0
  M118 P0 S{"Warning: filament profile '" ^ param.S ^ "' has a double quote in its name - not added to the profile list"}
  M99

M98 P"0:/sys/meltingplot/filament-profile/read-index.g"
while iterations < #global.filament_profiles
  if global.filament_profiles[iterations] == param.S
    M99

var file = "0:/sys/generated/filament-profiles.csv"
var sep = fileexists(var.file) ? "," : ""
echo >>>{var.file} var.sep ^ """" ^ param.S ^ """"
set global.filament_profiles = global.filament_profiles ^ vector(1, param.S)
