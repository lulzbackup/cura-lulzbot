;This G-Code has been generated specifically for the LulzBot TAZ 5 with standard extruder
G21                      ; set units to Millimetres
G90                      ; absolute positioning
M107                     ; disable fans
M82                      ; set extruder to absolute mode
G28 X0 Y0                ; home X and Y
G28 Z0                   ; home Z
G1 Z15.0 F{travel_speed} ; move extruder up
G92 E0                   ; set extruder position to 0
G1 F200 E0               ; prime the nozzle with filament
G92 E0                   ; re-set extruder position to 0
G1 F{travel_speed}       ; set travel speed
M203 X192 Y208 Z3        ; set limits on travel speed
M117 TAZ 5 Printing...   ; progress indicator message on LCD
