;This G-Code has been generated specifically for the LulzBot TAZ 5 with a HE 0.5mm Tool Head
M73 P0       ; clear GLCD progress bar
M75			 ; Start GLCD Timer
M140 S{material_bed_temperature_layer_0}    ; start bed heating up
G90                      ; absolute positioning
M107                     ; disable fans
M82                      ; set extruder to absolute mode
G28 X0 Y0                ; home X and Y
G28 Z0                   ; home Z
G1 Z15.0 F{speed_travel} ; move extruder up
M117 Heating...                     ; progress indicator message on LCD
M109 R{material_print_temperature_layer_0}  ; wait for extruder to reach printing temp
M190 R{material_bed_temperature_layer_0}    ; wait for bed to reach printing temp
G92 E0                   ; set extruder position to 0
G1 F200 E0               ; prime the nozzle with filament
G92 E0                   ; re-set extruder position to 0
G1 F{speed_travel}       ; set travel speed
M203 X192 Y208 Z3        ; set limits on travel speed
M117 TAZ 5 Printing...   ; progress indicator message on LCD
