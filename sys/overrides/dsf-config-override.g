; Machine specific DSF configuration, e.g. the network setup. Loaded from dsf-config.g.
; This file lives in sys/overrides/, the directory a config update never overwrites, so
; local changes survive. On an image-based machine the printer name comes from
; printer-name.g (mp-set-printer-name), which dsf-config.g loads after this file.

M550 P"Meltingplot-CHX-350-xxx"                      ; set printer name - replace xxx with your serial number

;M552 I0 P10.42.0.2 S1 ; enable ethernet with static IP
;M554 I0 P10.42.0.1 S10.42.0.1 ; Gateway and DNS Server
