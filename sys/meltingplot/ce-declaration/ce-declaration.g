; THIS FILE CONTAINS CE RELEVANT CONFIGURATIONS, ANY CHANGES TO THIS FILE MAY RESULT IN A LOST OF THE CE DECLARATION

M576 S0 F0                                              ; disable SPI slowdown

M950 J2 C"^io7.in"                                      ; create doorswitch left
M950 J3 C"^io8.in"                                      ; create doorswitch right
M950 J4 C"^io6.in"                                      ; create doorswitch hatch
M581 T3 P2:3:4 S1 R0                                    ; configure E1 as door switch (door closed)
M581 T4 P2:3:4 S0 R0                                    ; configure E1 as door switch (door opened)

M950 P3 C"out8"                                         ; Configure P3 as output for 230V Relais

;M42 P3 S0                                               ; Disable 230V Relais by default
;M913 X1 Y1 Z1 U1                                        ; reduce motor currents to 1%
;M913 X100 Y100 Z100 U100                                ; revert motor currents to 100%
M42 P3 S1                                               ; Enable 230V Relais

;M582 T4                                                 ; check door switch

M98 P"0:/sys/meltingplot/ce-declaration/reload-operating-mode.g"