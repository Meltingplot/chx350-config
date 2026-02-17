; param.D heater number
; param.P heater fault type

var fault_temp = heat.heaters[param.D].current

if job.file.fileName != null
  M25 ; pause print

; check if heater is above 50°C and in fault state
while heat.heaters[param.D].current > 50 && heat.heaters[0].state == "fault"
  var current_temp = heat.heaters[param.D].current
  ; check if temp is rising, after the heater fault
  if var.current_temp > (var.fault_temp + 10)
    M112 ; shut printer down -> disable heater power supplies
