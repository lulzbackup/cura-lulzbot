;This G-Code has been generated specifically for the LulzBot Mini with standard extruder
G26                                ; clear potential 'probe fail' condition
G21                                ; set units to Millimetres
M107                               ; disable fans
G90                                ; absolute positioning
M82                                ; set extruder to absolute mode
G92 E0                             ; set extruder position to 0
G28                                ; home all axes
M109 R{material_wipe_temperature}  ; wait for extruder to reach wiping temp
G1 Z150 E-30 F75                   ; retract filament
G1 X45 Y174 F11520                 ; move above wiper pad
G1 Z0  F1200                       ; push nozzle into wiper
G1 X45 Y174 Z-.5 F4000             ; wiping
G1 X55 Y172 Z-.5 F4000             ; wiping
G1 X45 Y174 Z0 F4000               ; wiping
G1 X55 Y172 F4000                  ; wiping
G1 X45 Y174 F4000                  ; wiping
G1 X55 Y172 F4000                  ; wiping
G1 X45 Y174 F4000                  ; wiping
G1 X55 Y172 F4000                  ; wiping
G1 X60 Y174 F4000                  ; wiping
G1 X80 Y172 F4000                  ; wiping
G1 X60 Y174 F4000                  ; wiping
G1 X80 Y172 F4000                  ; wiping
G1 X60 Y174 F4000                  ; wiping
G1 X90 Y172 F4000                  ; wiping
G1 X80 Y174 F4000                  ; wiping
G1 X100 Y172 F4000                 ; wiping
G1 X80 Y174 F4000                  ; wiping
G1 X100 Y172 F4000                 ; wiping
G1 X80 Y174 F4000                  ; wiping
G1 X100 Y172 F4000                 ; wiping
G1 X110 Y174 F4000                 ; wiping
G1 X100 Y172 F4000                 ; wiping
G1 X110 Y174 F4000                 ; wiping
G1 X100 Y172 F4000                 ; wiping
G1 X110 Y174 F4000                 ; wiping
G1 X115 Y172 Z-0.5 F1000           ; wiping
G1 Z10                             ; raise extruder
G28                                ; home
G4 S1                              ; pause
M400                               ; wait for moves to finish
G1 E0 F75                          ; prime tiny bit of filment into the nozzle
M400                               ; wait for moves to finish

