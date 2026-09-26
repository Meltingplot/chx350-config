; filament-profile/read-index.g
; Builds global.filament_profiles: the name of every filament profile the machine can
; load, for the material choice of macro change-filament. Neither RRF nor DSF can list a
; directory from a macro (no such function, and M20 answers the channel, not a variable),
; so the names come from two lists:
; - the profiles shipped with the config, written out below. A profile added to or
;   removed from filaments/ in the repo is added to or removed from this list;
; - the profiles created on the machine: one CSV line of quoted names in
;   sys/generated/filament-profiles.csv, appended by filament-profile/store-index.g
;   (macros create-filament-profile and repair-filament-profile, and the "Anderes
;   Profil" choice of change-filament).
; Only names whose temps.g exists are kept. A profile deleted on the machine drops out,
; and one without temps.g (created in DWC, not yet repaired) could not be loaded anyway:
; filament/on-load.g refuses it.
;   M98 P"0:/sys/meltingplot/filament-profile/read-index.g"
; fileread returns at most 40 elements per call (MaxFileReadArrayElements in RRF; DSF
; allows 50), so the machine file is read in pages of 40 and concatenated (^ on two
; arrays, RRF 3.7). A read past the end of the line returns {null} on the SBC (DSF,
; Functions.cs) and an empty array on standalone RRF (see spool/read-catalog.g); both
; are shorter than a page and end the loop, and the null is dropped with the filter.
; Every meta line stays under 255 characters, hence the list in several parts.

if global.debug
  echo "filament-profile/read-index.g"

var names = {"ABS","ASA","Flexfill 0.6 mm","Greentec Pro 0.6mm","Greentec Pro 1.2mm","HD Glass 0.6mm","Luvocom 3F PAHT 9936","Luvocom 3F PP CF 9928","Meltingplot PA6 CF HT 0.8mm"}
set var.names = var.names ^ {"Meltingplot PA6 CF HT 1.0mm","MetalFil 0.6mm","NOVAMID-1030-CF10 0.4mm","NOVAMID-1030-CF10 0.6mm","PETG","PETG-0.6mm","PLA 0.6 mm","PLA 0.8mm","PLA 1.2mm"}
set var.names = var.names ^ {"PLA BlackMatt 0.6mm","PLA NX2 black matt 0.8mm","PLA NX2 matt 0.8mm","PLA+","PolySmooth","Premium PLA","PythonFlex - 0.6mm","Re-PETG 0.6mm","STYX-12 0.6mm"}
set var.names = var.names ^ {"StoneFil 0.6mm","TPC","XPETG-0.6mm"}

var file = "0:/sys/generated/filament-profiles.csv"
if fileexists(var.file)
  var offset = 0
  while iterations < 10                ; 400 names - a guard, not a limit anyone reaches
    var page = fileread(var.file, var.offset, 40, ',')
    set var.names = var.names ^ var.page
    if #var.page < 40
      break
    set var.offset = var.offset + 40

set global.filament_profiles = vector(0, "")
while iterations < #var.names
  if var.names[iterations] != null
    if fileexists("0:/filaments/" ^ var.names[iterations] ^ "/temps.g")
      set global.filament_profiles = global.filament_profiles ^ vector(1, var.names[iterations])
