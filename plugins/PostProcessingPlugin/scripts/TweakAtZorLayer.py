# TweakAtZ script - Change printing parameters at a given height
# This script is the successor of the TweakAtZ plugin for legacy Cura.
# It contains code from the TweakAtZ plugin V1.0-V4.x and from the ExampleScript by Jaime van Kessel, Ultimaker B.V.
# It runs with the PostProcessingPlugin which is released under the terms of the AGPLv3 or higher.
# This script is licensed under the Creative Commons - Attribution - Share Alike (CC BY-SA) terms

#Authors of the TweakAtZ plugin / script:
# Written by Steven Morlock, smorloc@gmail.com
# Modified by Ricardo Gomez, ricardoga@otulook.com, to add Bed Temperature and make it work with Cura_13.06.04+
# Modified by Stefan Heule, Dim3nsioneer@gmx.ch since V3.0 (see changelog below)
# Modified by Jaime van Kessel (Ultimaker), j.vankessel@ultimaker.com to make it work for 15.10 / 2.x
# Modified by Ruben Dulek (Ultimaker), r.dulek@ultimaker.com, to debug.
# Modified by Brad Morgan, brad-morgan@comcast.net

##history / changelog:
##V3.0.1: TweakAtZ-state default 1 (i.e. the plugin works without any TweakAtZ comment)
##V3.1:   Recognizes UltiGCode and deactivates value reset, fan speed added, alternatively layer no. to tweak at,
##        extruder three temperature disabled by "#Ex3"
##V3.1.1: Bugfix reset flow rate
##V3.1.2: Bugfix disable TweakAtZ on Cool Head Lift
##V3.2:   Flow rate for specific extruder added (only for 2 extruders), bugfix parser,
##        added speed reset at the end of the print
##V4.0:   Progress bar, tweaking over multiple layers, M605&M606 implemented, reset after one layer option,
##        extruder three code removed, tweaking print speed, save call of Publisher class,
##        uses previous value from other plugins also on UltiGCode
##V4.0.1: Bugfix for doubled G1 commands
##V4.0.2: uses Cura progress bar instead of its own
##V4.0.3: Bugfix for cool head lift (contributed by luisonoff)
##V4.9.91: First version for Cura 15.06.x and PostProcessingPlugin
##V4.9.92: Modifications for Cura 15.10
##V4.9.93: Minor bugfixes (input settings) / documentation
##V4.9.94: Bugfix Combobox-selection; remove logger
##V5.0:   Bugfix for fall back after one layer and doubled G0 commands when using print speed tweak, Initial version for Cura 2.x
##V5.0.1: Bugfix for calling unknown property 'bedTemp' of previous settings storage and unkown variable 'speed'
##V5.1:   API Changes included for use with Cura 2.2
##V5.1.1: ?
##V5.1.2: Added test for ;LAYER=0 to avoid tweaking the start gcode.

## Uses -
## M220 S<factor in percent> - set speed factor override percentage
## M221 S<factor in percent> - set flow factor override percentage
## M221 S<factor in percent> T<0-#toolheads> - set flow factor override percentage for single extruder
## M104 S<temp> T<0-#toolheads> - set extruder <T> to target temperature <S>
## M140 S<temp> - set bed target temperature
## M106 S<PWM> - set fan speed to target speed <S>
## M605/606 to save and recall material settings on the UM2

from ..Script import Script
#from UM.Logger import Logger
import re

class TweakAtZorLayer(Script):
    version = "5.1.2"
    def __init__(self):
        super().__init__()

    def getSettingDataString(self):
        return """{
            "name":"TweakAtZ or Layer """ + self.version + """ (Experimental)",
            "key":"TweakAtZorLayer",
            "metadata": {},
            "version": 2,
            "settings":
            {
                "a_trigger":
                {
                    "label": "Trigger",
                    "description": "Trigger at height or at layer no.",
                    "type": "enum",
                    "options": {"height":"Height","layer_no":"Layer No."},
                    "default_value": "height"
                },
                "b_targetZ":
                {
                    "label": "Tweak Height",
                    "description": "Z height to tweak at",
                    "unit": "mm",
                    "type": "float",
                    "default_value": 5.0,
                    "minimum_value": "0",
                    "minimum_value_warning": "0.1",
                    "maximum_value_warning": "230",
                    "enabled": "a_trigger == 'height'"
                },
                "b_targetL":
                {
                    "label": "Tweak Layer",
                    "description": "Layer no. to tweak at",
                    "unit": "",
                    "type": "int",
                    "default_value": 1,
                    "minimum_value": "-100",
                    "minimum_value_warning": "-1",
                    "enabled": "a_trigger == 'layer_no'"
                },
                "c_behavior":
                {
                    "label": "Behavior",
                    "description": "Select behavior: Tweak value and keep it for the rest, Tweak value for single layer only",
                    "type": "enum",
                    "options": {"keep_value":"Keep value","single_layer":"Single Layer"},
                    "default_value": "keep_value"
                },
                "d_twLayers":
                {
                    "label": "No. Layers",
                    "description": "No. of layers used to tweak",
                    "unit": "",
                    "type": "int",
                    "default_value": 1,
                    "minimum_value": "1",
                    "maximum_value_warning": "50",
                    "enabled": "c_behavior == 'keep_value'"
                },
                "e1_Tweak_speed":
                {
                    "label": "Tweak Speed",
                    "description": "Select if total speed (print and travel) has to be tweaked",
                    "type": "bool",
                    "default_value": false
                },
                "e2_speed":
                {
                    "label": "Speed",
                    "description": "New total speed (print and travel)",
                    "unit": "%",
                    "type": "int",
                    "default_value": 100,
                    "minimum_value": "1",
                    "minimum_value_warning": "10",
                    "maximum_value_warning": "200",
                    "enabled": "e1_Tweak_speed"
                },
                "f1_Tweak_printspeed":
                {
                    "label": "Tweak Print Speed",
                    "description": "Select if print speed has to be tweaked",
                    "type": "bool",
                    "default_value": false
                },
                "f2_printspeed":
                {
                    "label": "Print Speed",
                    "description": "New print speed",
                    "unit": "%",
                    "type": "int",
                    "default_value": 100,
                    "minimum_value": "1",
                    "minimum_value_warning": "10",
                    "maximum_value_warning": "200",
                    "enabled": "f1_Tweak_printspeed"
                },
                "g1_Tweak_flowrate":
                {
                    "label": "Tweak Flow Rate",
                    "description": "Select if flow rate has to be tweaked",
                    "type": "bool",
                    "default_value": false
                },
                "g2_flowrate":
                {
                    "label": "Flow Rate",
                    "description": "New Flow rate",
                    "unit": "%",
                    "type": "int",
                    "default_value": 100,
                    "minimum_value": "1",
                    "minimum_value_warning": "10",
                    "maximum_value_warning": "200",
                    "enabled": "g1_Tweak_flowrate"
                },
                "g3_Tweak_flowrateOne":
                {
                    "label": "Tweak Flow Rate 1",
                    "description": "Select if first extruder flow rate has to be tweaked",
                    "type": "bool",
                    "default_value": false
                },
                "g4_flowrateOne":
                {
                    "label": "Flow Rate One",
                    "description": "New Flow rate Extruder 1",
                    "unit": "%",
                    "type": "int",
                    "default_value": 100,
                    "minimum_value": "1",
                    "minimum_value_warning": "10",
                    "maximum_value_warning": "200",
                    "enabled": "g3_Tweak_flowrateOne"
                },
                "g5_Tweak_flowrateTwo":
                {
                    "label": "Tweak Flow Rate 2",
                    "description": "Select if second extruder flow rate has to be tweaked",
                    "type": "bool",
                    "default_value": false
                },
                "g6_flowrateTwo":
                {
                    "label": "Flow Rate two",
                    "description": "New Flow rate Extruder 2",
                    "unit": "%",
                    "type": "int",
                    "default_value": 100,
                    "minimum_value": "1",
                    "minimum_value_warning": "10",
                    "maximum_value_warning": "200",
                    "enabled": "g5_Tweak_flowrateTwo"
                },
                "h1_Tweak_bedTemp":
                {
                    "label": "Tweak Bed Temp",
                    "description": "Select if Bed Temperature has to be tweaked",
                    "type": "bool",
                    "default_value": false
                },
                "h2_bedTemp":
                {
                    "label": "Bed Temp",
                    "description": "New Bed Temperature",
                    "unit": "C",
                    "type": "float",
                    "default_value": 60,
                    "minimum_value": "0",
                    "minimum_value_warning": "30",
                    "maximum_value_warning": "120",
                    "enabled": "h1_Tweak_bedTemp"
                },
                "i1_Tweak_extruderOne":
                {
                    "label": "Tweak Extruder 1 Temp",
                    "description": "Select if First Extruder Temperature has to be tweaked",
                    "type": "bool",
                    "default_value": false
                },
                "i2_extruderOne":
                {
                    "label": "Extruder 1 Temp",
                    "description": "New First Extruder Temperature",
                    "unit": "C",
                    "type": "float",
                    "default_value": 190,
                    "minimum_value": "0",
                    "minimum_value_warning": "160",
                    "maximum_value_warning": "250",
                    "enabled": "i1_Tweak_extruderOne"
                },
                "i3_Tweak_extruderTwo":
                {
                    "label": "Tweak Extruder 2 Temp",
                    "description": "Select if Second Extruder Temperature has to be tweaked",
                    "type": "bool",
                    "default_value": false
                },
                "i4_extruderTwo":
                {
                    "label": "Extruder 2 Temp",
                    "description": "New Second Extruder Temperature",
                    "unit": "C",
                    "type": "float",
                    "default_value": 190,
                    "minimum_value": "0",
                    "minimum_value_warning": "160",
                    "maximum_value_warning": "250",
                    "enabled": "i3_Tweak_extruderTwo"
                },
                "j1_Tweak_fanSpeed":
                {
                    "label": "Tweak Fan Speed",
                    "description": "Select if Fan Speed has to be tweaked",
                    "type": "bool",
                    "default_value": false
                },
                "j2_fanSpeed":
                {
                    "label": "Fan Speed",
                    "description": "New Fan Speed (0-255)",
                    "unit": "PWM",
                    "type": "int",
                    "default_value": 255,
                    "minimum_value": "0",
                    "minimum_value_warning": "15",
                    "maximum_value_warning": "255",
                    "enabled": "j1_Tweak_fanSpeed"
                }
            }
        }"""

    def getValue(self, line, key, default = None): #replace default getvalue due to comment-reading feature
        if not key in line or (";" in line and line.find(key) > line.find(";") and
                                   not ";TweakAtZ" in key and not ";LAYER:" in key):
            return default
        subPart = line[line.find(key) + len(key):] #allows for string lengths larger than 1
        if ";TweakAtZ" in key:
            m = re.search("^[0-4]", subPart)
        elif ";LAYER:" in key:
            m = re.search("^[+-]?[0-9]*", subPart)
        else:
            #the minus at the beginning allows for negative values, e.g. for delta printers
            m = re.search("^[-]?[0-9]*\.?[0-9]*", subPart)
        if m == None:
            return default
        try:
            return float(m.group(0))
        except:
            return default

    def execute(self, data):
        #Check which tweaks should apply
        TweakProp = {"speed": self.getSettingValueByKey("e1_Tweak_speed"),
             "flowrate": self.getSettingValueByKey("g1_Tweak_flowrate"),
             "flowrateOne": self.getSettingValueByKey("g3_Tweak_flowrateOne"),
             "flowrateTwo": self.getSettingValueByKey("g5_Tweak_flowrateTwo"),
             "bedTemp": self.getSettingValueByKey("h1_Tweak_bedTemp"),
             "extruderOne": self.getSettingValueByKey("i1_Tweak_extruderOne"),
             "extruderTwo": self.getSettingValueByKey("i3_Tweak_extruderTwo"),
             "fanSpeed": self.getSettingValueByKey("j1_Tweak_fanSpeed")}
        TweakPrintSpeed = self.getSettingValueByKey("f1_Tweak_printspeed")
        TweakStrings = {"speed": "M220 S%f\n",
            "flowrate": "M221 S%f\n",
            "flowrateOne": "M221 T0 S%f\n",
            "flowrateTwo": "M221 T1 S%f\n",
            "bedTemp": "M140 S%f\n",
            "extruderOne": "M104 S%f T0\n",
            "extruderTwo": "M104 S%f T1\n",
            "fanSpeed": "M106 S%d\n"}
        target_values = {"speed": self.getSettingValueByKey("e2_speed"),
            "printspeed": self.getSettingValueByKey("f2_printspeed"),
            "flowrate": self.getSettingValueByKey("g2_flowrate"),
            "flowrateOne": self.getSettingValueByKey("g4_flowrateOne"),
            "flowrateTwo": self.getSettingValueByKey("g6_flowrateTwo"),
            "bedTemp": self.getSettingValueByKey("h2_bedTemp"),
            "extruderOne": self.getSettingValueByKey("i2_extruderOne"),
            "extruderTwo": self.getSettingValueByKey("i4_extruderTwo"),
            "fanSpeed": self.getSettingValueByKey("j2_fanSpeed")}
        old = {"speed": -1, "flowrate": -1, "flowrateOne": -1, "flowrateTwo": -1, "platformTemp": -1, "extruderOne": -1,
            "extruderTwo": -1, "bedTemp": -1, "fanSpeed": -1, "state": -1}
        twLayers = self.getSettingValueByKey("d_twLayers")
        if self.getSettingValueByKey("c_behavior") == "single_layer":
            behavior = 1
        else:
            behavior = 0
        try:
            twLayers = max(int(twLayers),1) #for the case someone entered something as "funny" as -1
        except:
            twLayers = 1
        pres_ext = 0
        done_layers = 0
        z = 0
        x = None
        y = None
        layer = -100000 #layer no. may be negative (raft) but never that low
        # state 0: deactivated, state 1: activated, state 2: active, but below z,
        # state 3: active and partially executed (multi layer), state 4: active and passed z
        state = 1
        # IsUM2: Used for reset of values (ok for Marlin/Sprinter),
        # has to be set to 1 for UltiGCode (work-around for missing default values)
        IsUM2 = False
        oldValueUnknown = False
        TWinstances = 0
        layers_started = False

        if self.getSettingValueByKey("a_trigger") == "layer_no":
            targetL_i = int(self.getSettingValueByKey("b_targetL"))
            targetZ = 100000
        else:
            targetL_i = -100000
            targetZ = self.getSettingValueByKey("b_targetZ")
        index = 0
        for active_layer in data:
            modified_gcode = ""
            lines = active_layer.split("\n")
            for line in lines:
                if ";Generated with Cura_SteamEngine" in line:
                    TWinstances += 1
                    modified_gcode += ";TweakAtZ instances: %d\n" % TWinstances
                if not ("M84" in line or "M25" in line or ("G1" in line and TweakPrintSpeed and (state==3 or state==4)) or
                                ";TweakAtZ instances:" in line):
                    modified_gcode += line + "\n"
                IsUM2 = ("FLAVOR:UltiGCode" in line) or IsUM2 #Flavor is UltiGCode!
                if ";TweakAtZ-state" in line: #checks for state change comment
                    state = self.getValue(line, ";TweakAtZ-state", state)
                if ";TweakAtZ instances:" in line:
                    try:
                        tempTWi = int(line[20:])
                    except:
                        tempTWi = TWinstances
                    TWinstances = tempTWi
                if ";Small layer" in line: #checks for begin of Cool Head Lift
                    old["state"] = state
                    state = 0
                if ";LAYER:0" in line:
                    layers_started = True
                    continue
                if not layers_started:
                    continue
                if ";LAYER:" in line: #new layer no. found
                    if state == 0:
                        state = old["state"]
                    layer = self.getValue(line, ";LAYER:", layer)
                    if targetL_i > -100000: #target selected by layer no.
                        if (state == 2 or targetL_i == 0) and layer == targetL_i: #determine targetZ from layer no.; checks for tweak on layer 0
                            state = 2
                            targetZ = z + 0.001
                if (self.getValue(line, "T", None) is not None) and (self.getValue(line, "M", None) is None): #looking for single T-cmd
                    pres_ext = self.getValue(line, "T", pres_ext)
                if "M190" in line or "M140" in line and state < 3: #looking for bed temp, stops after target z is passed
                    old["bedTemp"] = self.getValue(line, "S", old["bedTemp"])
                if "M109" in line or "M104" in line and state < 3: #looking for extruder temp, stops after target z is passed
                    if self.getValue(line, "T", pres_ext) == 0:
                        old["extruderOne"] = self.getValue(line, "S", old["extruderOne"])
                    elif self.getValue(line, "T", pres_ext) == 1:
                        old["extruderTwo"] = self.getValue(line, "S", old["extruderTwo"])
                if "M107" in line: #fan is stopped; is always updated in order not to miss switch off for next object
                    old["fanSpeed"] = 0
                if "M106" in line and state < 3: #looking for fan speed
                    old["fanSpeed"] = self.getValue(line, "S", old["fanSpeed"])
                if "M221" in line and state < 3: #looking for flow rate
                    tmp_extruder = self.getValue(line,"T",None)
                    if tmp_extruder == None: #check if extruder is specified
                        old["flowrate"] = self.getValue(line, "S", old["flowrate"])
                    elif tmp_extruder == 0: #first extruder
                        old["flowrateOne"] = self.getValue(line, "S", old["flowrateOne"])
                    elif tmp_extruder == 1: #second extruder
                        old["flowrateOne"] = self.getValue(line, "S", old["flowrateOne"])
                if ("M84" in line or "M25" in line):
                    if state>0 and TweakProp["speed"]: #"finish" commands for UM Original and UM2
                        modified_gcode += "M220 S100 ; speed reset to 100% at the end of print\n"
                        modified_gcode += "M117                     \n"
                    modified_gcode += line + "\n"
                if "G1" in line or "G0" in line:
                    newZ = self.getValue(line, "Z", z)
                    x = self.getValue(line, "X", None)
                    y = self.getValue(line, "Y", None)
                    e = self.getValue(line, "E", None)
                    f = self.getValue(line, "F", None)
                    if 'G1' in line and TweakPrintSpeed and (state==3 or state==4):
                        # check for pure print movement in target range:
                        if x != None and y != None and f != None and e != None and newZ==z:
                            modified_gcode += "G1 F%d X%1.3f Y%1.3f E%1.5f\n" % (int(f / 100.0 * float(target_values["printspeed"])), self.getValue(line, "X"),
                                                                          self.getValue(line, "Y"), self.getValue(line, "E"))
                        else: #G1 command but not a print movement
                            modified_gcode += line + "\n"
                    # no tweaking on retraction hops which have no x and y coordinate:
                    if (newZ != z) and (x is not None) and (y is not None):
                        z = newZ
                        if z < targetZ and state == 1:
                            state = 2
                        if z >= targetZ and state == 2:
                            state = 3
                            done_layers = 0
                            for key in TweakProp:
                                if TweakProp[key] and old[key]==-1: #old value is not known
                                    oldValueUnknown = True
                            if oldValueUnknown: #the tweaking has to happen within one layer
                                twLayers = 1
                                if IsUM2: #Parameters have to be stored in the printer (UltiGCode=UM2)
                                    modified_gcode += "M605 S%d;stores parameters before tweaking\n" % (TWinstances-1)
                            if behavior == 1: #single layer tweak only and then reset
                                twLayers = 1
                            if TweakPrintSpeed and behavior == 0:
                                twLayers = done_layers + 1
                        if state==3:
                            if twLayers-done_layers>0: #still layers to go?
                                if targetL_i > -100000:
                                    modified_gcode += ";TweakAtZ V%s: executed at Layer %d\n" % (self.version,layer)
                                    modified_gcode += "M117 Printing... tw@L%4d\n" % layer
                                else:
                                    modified_gcode += (";TweakAtZ V%s: executed at %1.2f mm\n" % (self.version,z))
                                    modified_gcode += "M117 Printing... tw@%5.1f\n" % z
                                for key in TweakProp:
                                    if TweakProp[key]:
                                        modified_gcode += TweakStrings[key] % float(old[key]+(float(target_values[key])-float(old[key]))/float(twLayers)*float(done_layers+1))
                                done_layers += 1
                            else:
                                state = 4
                                if behavior == 1: #reset values after one layer
                                    if targetL_i > -100000:
                                        modified_gcode += ";TweakAtZ V%s: reset on Layer %d\n" % (self.version,layer)
                                    else:
                                        modified_gcode += ";TweakAtZ V%s: reset at %1.2f mm\n" % (self.version,z)
                                    if IsUM2 and oldValueUnknown: #executes on UM2 with Ultigcode and machine setting
                                        modified_gcode += "M606 S%d;recalls saved settings\n" % (TWinstances-1)
                                    else: #executes on RepRap, UM2 with Ultigcode and Cura setting
                                        for key in TweakProp:
                                            if TweakProp[key]:
                                                modified_gcode += TweakStrings[key] % float(old[key])
                        # re-activates the plugin if executed by pre-print G-command, resets settings:
                        if (z < targetZ or layer == 0) and state >= 3: #resets if below tweak level or at level 0
                            state = 2
                            done_layers = 0
                            if targetL_i > -100000:
                                modified_gcode += ";TweakAtZ V%s: reset below Layer %d\n" % (self.version,targetL_i)
                            else:
                                modified_gcode += ";TweakAtZ V%s: reset below %1.2f mm\n" % (self.version,targetZ)
                            if IsUM2 and oldValueUnknown: #executes on UM2 with Ultigcode and machine setting
                                modified_gcode += "M606 S%d;recalls saved settings\n" % (TWinstances-1)
                            else: #executes on RepRap, UM2 with Ultigcode and Cura setting
                                for key in TweakProp:
                                    if TweakProp[key]:
                                        modified_gcode += TweakStrings[key] % float(old[key])
            data[index] = modified_gcode
            index += 1
        return data
