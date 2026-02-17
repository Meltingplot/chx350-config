; THIS FILE CONTAINS CE RELEVANT CONFIGURATIONS, ANY CHANGES TO THIS FILE MAY RESULT IN A LOST OF THE CE DECLARATION
if global.debug
  echo "trigger3.g executed"
  echo "global.machine_mode: " ^ global.machine_mode

if(sensors.gpIn[2].value == 1 && sensors.gpIn[3].value == 1 && global.door_left_switch_checked == true && global.door_right_switch_checked == true)
  if (heat.heaters[0].active > 0)
    M400
    G4 P500 ; wait for the switch to automatic mode
    while global.machine_mode != "automatic" && iterations < 5
      M400
      G4 P500
    if global.machine_mode == "automatic"
      M291 R"Heizelemente" P"Druckbettheizung und Hotend aktivieren?" K{"Ja","Nein"} S4 T30 F1 J2
      if (input == 0)
        M144 P0 S1 ; activate bed heater
        M568 P0 A2 ; activate hotend heater
