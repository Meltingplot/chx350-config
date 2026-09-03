var bed_temp = 90.0 ; Bed temperature in °C
var tool_temp = 180.0 ; Tool temperature in °C

var wait_for_heatsoak = true

var bed_heater = heat.bedHeaters[0]
var tool_heater = tools[0].heaters[0]

if heat.heaters[var.bed_heater].active != 0
  set var.bed_temp = heat.heaters[var.bed_heater].active

if heat.heaters[var.tool_heater].active != 0
  set var.tool_temp = heat.heaters[var.tool_heater].active

if heat.heaters[var.bed_heater].current > (var.bed_temp - 10) && heat.heaters[var.tool_heater].current > (var.tool_temp - 50)
  set var.wait_for_heatsoak = false

M140 H0 S{var.bed_temp} R{var.bed_temp-20} ; set bed temperature to 90°C and ramp rate to 60°C
M568 P0 S{var.tool_temp} R{var.tool_temp-100} A2; set hotend temperature to 180°C and ramp rate to 80°C

M291 P"Waiting for Heaters. This Message may disappear but the macro is still executed! Be patient." ; display message to user
M116 ; wait for all heaters to reach their target temperatures

if var.wait_for_heatsoak
  M291 P"Waiting for heat soak. This takes 5 minutes." S1 ; notify user about heat soak
  G4 S{5 * 60} ; wait for 5 minutes to allow heat soak

G28
M291 P"Heatup and homing completed. The printer is now ready for the next steps." S2 ; notify user