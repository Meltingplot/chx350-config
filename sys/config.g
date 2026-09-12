; Configuration file for Duet 3 (firmware version 3.6.1)
; executed by the firmware on start-up

M98 P"0:/sys/meltingplot/globals"                       ; Load Global Variables
M98 P"0:/sys/meltingplot/ce-declaration/e-stop.g"

; Led
M950 E0 C"led" Q3000000 T1 U60 ; create ARGB leds in waterpump and hood
M98 P"0:/sys/meltingplot/set_led_color" C"yellow"

; Network Ethernet
;M551 P"meltingplot"                                    ; set password

; Drives
; disabled in closed loop mode as X and Y are driven by external drivers
M569 P0 S0                                              ; physical drive 0 goes backwards (left front)
M569 P1 S0                                              ; physical drive 1 goes forwards (left rear)
M569 P2 S0                                              ; physical drive 2 goes backwards (right rear)
M569 P3 S0                                              ; physical drive 3 goes backwards (rear front)

G4 S5                                                   ; wait for expansion boards

; wait for all boards to come up
while #boards < 7
  G4 P50
  if iterations > 200
    echo "Error: CAN Communication error! Abort!"
    M112

;          U 53.0 +------------------------------------+
;        X2 51.0 /                                    /|
;               /                                    / |
;              /                                    /  |
;      Y 52.0 +------------------------------------+   |
;     X1 50.0 |                                    |   |
;             |                                    |  /
;          Z2 |               front                | / Z3
;             |                                    |/
;        Z1   +------------------------------------+ Z4

; Configure the Duet 3 Expansion 1HCL board at CAN address 50 with a Duet 3 magnetic encoder, warn if 2 fullstep threshold exceeded, error if 4 full steps threshold exceeded.
M569.1 P50.0 T3 E6.0:20.0 S200 R160 I200 D0.08 V320 A160000 H0.3
if result != 0	
  echo "Error - abort!"	
  M112

M569 P50.0 D2 S1 ; Configure the motor on the Duet 3 Expansion 1HCL controller at can address 50 as being in open-loop drive mode (D2) and reversed (S0)

; Configure the Duet 3 Expansion 1HCL board at CAN address 51 with a Duet 3 magnetic encoder, warn if 2 fullstep threshold exceeded, error if 4 full steps threshold exceeded.
M569.1 P51.0 T3 E6.0:20.0 S200 R160 I200 D0.08 V320 A160000 H0.3
if result != 0	
  echo "Error - abort!"	
  M112

M569 P51.0 D2 S0 ; Configure the motor on the Duet 3 Expansion 1HCL controller at can address 51 as being in open-loop drive mode (D2) reversed (S1)

; Configure the Duet 3 Expansion 1HCL board at CAN address 52 with a Duet 3 magnetic encoder, warn if 2 fullstep threshold exceeded, error if 4 full steps threshold exceeded.
M569.1 P52.0 T3 E6.0:20.0 S200 R160 I120 D0.1 V240 A112000 H0.3
if result != 0	
  echo "Error - abort!"	
  M112

M569 P52.0 D2 S0 ; Configure the motor on the Duet 3 Expansion 1HCL controller at can address 51 as being in open-loop drive mode (D2) reversed (S1)

; Configure the Duet 3 Expansion 1HCL board at CAN address 53 with a Duet 3 magnetic encoder, warn if 2 fullstep threshold exceeded, error if 4 full steps threshold exceeded.
M569.1 P53.0 T3 E6.0:20.0 S200 R160 I120 D0.1 V240 A112000 H0.3
if result != 0	
  echo "Error - abort!"	
  M112

M569 P53.0 D2 S0 ; Configure the motor on the Duet 3 Expansion 1HCL controller at can address 51 as being in open-loop drive mode (D2) reversed (S1)

M569 P20.0 S1                                           ; physical drive 20.0 on toolboard goes forward (E0)

M400                                                    ; SBC specific wait

M584 X50.0:51.0 Y52.0 U53.0 Z0:1:2:3 E20.0              ; set drive mapping
if result != 0
  echo "Error: M584 failed!"
  M112
M400                                                    ; SBC specific wait

M669 K5 X1:1:0:-1 Y0:1:0:0 Z0:0:1:0 U0:0:0:1 S10 T0.1   ; select CoreIDX mode and enable segmentation

M400                                                    ; SBC specific wait

M350 E16 I1                                             ; configure microstepping with interpolation
M350 Z32 I1                                             ; configure microstepping with interpolation
M350 X64 Y64 U64 I0                                     ; configure microstepping without interpolation
M400                                                    ; SBC specific wait
M92 X320 Y320 Z1600 U320 E800                           ; set steps per mm
M400                                                    ; SBC specific wait

; General preferences
G90                                                     ; send absolute coordinates...
M83                                                     ; ...but relative extruder moves

M98 P"0:/sys/meltingplot/ce-declaration/operating-mode/default.g"

M593 P"mzv" F32.8 S0.07                                 ; cancle ringing at 37Hz zvd will cover a range from around 20 - 60 hz
                                                        ; do not use zvddd, ei2 or ei3 as the TOOL1LC can not handle the load of it in most cases.

; Axis Limits
M208 X0 Y0 Z0 U0 S1                                     ; set axis minima
M208 X880 Y422 Z945 U422 S0                             ; set axis maxima

; Endstops
M574 X2 S3                                              ; configure sensorless endstop on high end on X
M574 Y1 S3                                              ; configure sensorless endstop on low end on Y
M574 Z2 S4                                              ; configure sensorless endstop on high end of Z
M574 U2 S3                                              ; configure sensorless endstop on high end on U

; Heaters
M950 H0 C"nil"                                          ; clear heater 0
M950 H1 C"nil"                                          ; clear heater 1

; Bed Heaters
M308 S0 P"temp0" Y"thermistor" T100000 B4598 C8.68e-08 A"bed" ; configure sensor 0 as thermistor on pin temp0
M950 H0 C"out7" T0 Q0.5                                 ; create bed heater output on out7 and map it to sensor 0 and set PWM 25Hz
M307 H0 R0.25 K0.1:0.000 D3.00 E1.35 S1.00 B0           ; disable bang-bang mode for the bed heater and set PWM limit
M140 P0 H0                                              ; map heater0 to bed
M143 H0 S120                                            ; set temperature limit for heater 0 to 120C
M570 H0 P5 T10 S10                                      ; Enable heater fault detection (Trigger Time 5sec, temp deviation 10°, cancel print after 10min) 

; Hotend
M308 S2 P"20.temp0" Y"pt1000" A"left"                   ; configure sensor 2 as PT1000 on pin 20.temp0
M950 H1 C"20.out0" T2                                   ; create nozzle heater output on out1 and map it to sensor 2
M143 H1 S300                                            ; set temperature limit for heater 2 to 300C
M307 H1 R1.962 K0.205:0.114 D5.81 E1.35 S1.00 B0 V24.0  ; disable bang-bang mode for the nozzle heater and set PWM limit
M570 H1 P10 T15 S10                                     ; Enable heater fault detection (Trigger Time 10sec, temp deviation 15°, cancel print after 10min)

; Fans
; Numbering follows the slicer convention: P0 = part cooling, P2 = auxiliary part
; cooling, P3 = exhaust / chamber fan. Machine internal fans start at P4 so that a
; slicer can never address them. P2 and P3 are optional hardware and only exist if
; enabled by has_aux_fan / has_exhaust_fan in global-override.g.
M950 F0 C"!20.out1+out1.tach" Q250                      ; create fan 0 (part cooling fan) on pin 20.out1 and set its frequency
M106 P0 S0 H-1 C"part cooling"                          ; set fan 0 value. Thermostatic control is turned off
; Part cooling fan #2 has no PWM channel of its own - it is driven by the PWM of fan 0
; and 20.out2 only switches its lowside mosfet, i.e. it enables the fan. The mosfet must
; therefore always be on, hence the thermostatic setting on sensor 2 with T10 (= always).
M950 F1 C"20.out2+out2.tach" Q250                       ; create fan 1 (part cooling fan #2 enable) on pin 20.out2 and set its frequency
M106 P1 S1 H2 T10 L1.0 X1.0 C"part cooling #2"          ; keep the enable on whenever the hotend is above 10C
if global.has_aux_fan
  M950 F2 C"out2" Q250                                  ; create fan 2 (aux fan) on pin out2 and set its frequency
  M106 P2 S0 H-1 C"aux"                                 ; set fan 2 value. Thermostatic control is turned off
if global.has_exhaust_fan
  M950 F3 C"out1" Q250                                  ; create fan 3 (exhaust fan) on pin out1 and set its frequency
  M106 P3 S0 H-1 C"exhaust"                             ; set fan 3 value. Thermostatic control is turned off
M950 F4 C"out4+out4.tach" Q450                          ; create fan 4 (lower radiator fan) on pin out4 and set its frequency
M106 P4 S0 H2 T40 L1.0 X1.0 C"lower radiator"           ; set fan 4 value. Thermostatic control on sensor 2
M950 F5 C"out5+out5.tach" Q450                          ; create fan 5 (upper radiator fan) on pin out5 and set its frequency
M106 P5 S0 H2 T40 L1.0 X1.0 C"upper radiator"           ; set fan 5 value. Thermostatic control on sensor 2
M950 F6 C"!out6+out6.tach" Q250                         ; create fan 6 (water pump) on pin out6 and set its frequency
M106 P6 S0 H2 T40:100 L0.75 X1.0 C"water pump"          ; set fan 6 value. Thermostatic control on sensor 2

; Tools
M563 P0 D0 H1 F0                                        ; define tool 0
G10 P0 X0 Y0 Z0                                         ; set tool 0 axis offsets
M568 P0 R0 S0 A0                                        ; set initial tool 0 active and standby temperatures to 0C

M404 N2.85
M200 D2.85 S0                                           ; set filament diameter to 2.85mm

; Scanning Z probe
M558 K0 P11 C"60.i2c.ldc1612" F6000 T60000 R0.5 A2      ; set Z probe type to scanning z probe feed rate and travel speed
if result != 0
  echo "Error: M558 failed!"
  M112
M308 A"SZP coil" S4 Y"thermistor" P"60.temp0"           ; thermistor on coil
G31 K0 Z2 X23.2 Y12.3 P9000                             ; set Z probe trigger value, offset and trigger height
M98 P"0:/sys/meltingplot/z-probe/szp_standard_mode.g"
M557 X{sensors.probes[0].offsets[0],move.axes[0].max-sensors.probes[0].offsets[0]} Y{sensors.probes[0].offsets[1],move.axes[1].max-sensors.probes[0].offsets[1]} P40:21                        ; define mesh grid

M376 H5                                                 ; taper out z correction over 5mm height

; Accelerometer
M955 P0 C"20.i2c.lis" I05                                          ; configure integrated accelerometer on the toolboard (CAN address 20), orientation verified on the machine
M955 P0 C"60.i2c.lis" I25                                          ; configure accelerometer on the scanning z probe (CAN address 60), orientation verified on the machine

M671 X-99.60:-99.60:940.40:940.40 Y58.85:388.50:388.50:58.85 S5          ; Z leadscrews are at (-99.60,58.85), (-99.60,388.50), (940.40,388.50) and (940.40, 58.85)


; Servo
M950 S6 C"out9" ; assign GPIO port 1 to out9 (Servo header), servo mode
M280 P6 S100  ; set 104deg servo position on GPIO port 1

M929 P"0:/sys/eventlog.log" S2                              ; Enable Event Logging

M501                                                    ; load saved parameters from non-volatile memory
M98 P"0:/sys/meltingplot/machine-override"              ; Load Machine specific overrides
M98 P"0:/sys/meltingplot/ce-declaration/ce-declaration.g" ; Load CE Requirements
