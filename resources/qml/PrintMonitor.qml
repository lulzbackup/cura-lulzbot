// Copyright (c) 2017 Ultimaker B.V.
// Cura is released under the terms of the AGPLv3 or higher.

import QtQuick 2.2
import QtQuick.Controls 1.1
import QtQuick.Controls.Styles 1.1
import QtQuick.Layouts 1.1
import QtQuick.Dialogs 1.2

import UM 1.2 as UM
import Cura 1.0 as Cura

ScrollView
{
    property var connectedPrinter: Cura.MachineManager.printerOutputDevices.length >= 1 ? Cura.MachineManager.printerOutputDevices[0] : null

    style: UM.Theme.styles.scrollview;
    flickableItem.flickableDirection: Flickable.VerticalFlick;

	Column
	{
	    id: printMonitor

        signal receive( string error )

        onReceive:
        {
            message_dialog.icon = StandardIcon.Critical
            message_dialog.text = error
            message_dialog.open()
        }

        UM.SettingPropertyProvider
        {
            id: printTemperatureProvider

            containerStackId: Cura.MachineManager.activeMachineId
            key: "material_print_temperature"
            watchedProperties: [ "value" ]
        }

	    Cura.ExtrudersModel
	    {
	        id: extrudersModel
	        simpleNames: true
	    }

	    Rectangle
	    {
	        id: connectedPrinterHeader
	        width: parent.width
	        height: childrenRect.height + UM.Theme.getSize("default_margin").height * 2
	        color: UM.Theme.getColor("setting_category")

	        Label
	        {
	            id: connectedPrinterNameLabel
	            text: connectedPrinter != null ? connectedPrinter.name : catalog.i18nc("@info:status", "No printer connected")
	            font: UM.Theme.getFont("large")
	            color: UM.Theme.getColor("text")
	            anchors.left: parent.left
	            anchors.top: parent.top
	            anchors.margins: UM.Theme.getSize("default_margin").width
	        }
	        Label
	        {
	            id: connectedPrinterAddressLabel
	            text: (connectedPrinter != null && connectedPrinter.address != null) ? connectedPrinter.address : ""
	            font: UM.Theme.getFont("small")
	            color: UM.Theme.getColor("text_inactive")
	            anchors.top: parent.top
	            anchors.right: parent.right
	            anchors.margins: UM.Theme.getSize("default_margin").width
	        }
	        Label
	        {
	            text: connectedPrinter != null ? connectedPrinter.connectionText : catalog.i18nc("@info:status", "The printer is not connected.")
	            color: connectedPrinter != null && connectedPrinter.acceptsCommands ? UM.Theme.getColor("setting_control_text") : UM.Theme.getColor("setting_control_disabled_text")
	            font: UM.Theme.getFont("very_small")
	            wrapMode: Text.WordWrap
	            anchors.left: parent.left
	            anchors.leftMargin: UM.Theme.getSize("default_margin").width
	            anchors.right: parent.right
	            anchors.rightMargin: UM.Theme.getSize("default_margin").width
	            anchors.top: connectedPrinterNameLabel.bottom
	        }
	    }


	    Rectangle
	    {
	        color: UM.Theme.getColor("sidebar_lining")
	        width: parent.width
	        height: childrenRect.height

	        Flow
	        {
	            id: extrudersGrid
	            spacing: UM.Theme.getSize("sidebar_lining_thin").width
	            width: parent.width

	            Repeater
	            {

	                id: extrudersRepeater
                    model: machineExtruderCount.properties.value

	                delegate: Rectangle
	                {
	                    id: extruderRectangle
	                    color: UM.Theme.getColor("sidebar")
	                    width: index == machineExtruderCount.properties.value - 1 && index % 2 == 0 ? extrudersGrid.width : extrudersGrid.width / 2 - UM.Theme.getSize("sidebar_lining_thin").width / 2
	                    height: UM.Theme.getSize("sidebar_extruder_box").height

                        GridLayout
                        {
                            id: gridLayout
                            columns: 5
                            rows: 2
                            rowSpacing: UM.Theme.getSize("button_spacing").width
                            columnSpacing: UM.Theme.getSize("button_spacing").width
                            anchors.fill: parent
                            anchors.centerIn: parent
                            anchors.leftMargin: UM.Theme.getSize("button_spacing").width
                            anchors.rightMargin: UM.Theme.getSize("button_spacing").width


                            Label //Extruder name.
                            {
                                id: extruderName
                                Layout.row: 1
                                Layout.column: 1

                                text: ExtruderManager.getExtruderName(index) != "" ? ExtruderManager.getExtruderName(index) : catalog.i18nc("@label", "Hotend")
                                color: UM.Theme.getColor("text")
                                font: UM.Theme.getFont("default")
                                anchors.margins: UM.Theme.getSize("default_margin").width
                            }


                            Label //Temperature indication.
                            {
                                id: extruderTemperature
                                Layout.row: 1
                                Layout.column: 2

                                text:
                                {
                                    if( index == 0)
                                        (connectedPrinter != null && connectedPrinter.hotendIds[index] != null && connectedPrinter.hotendTemperatures[index] != null && connectedPrinter.hotendTemperatures[index] != 0) ? Math.round(connectedPrinter.hotendTemperatures[index]) + "°C" : ""
                                    else
                                        (connectedPrinter != null && connectedPrinter.hotendTemperatures[index] != null && connectedPrinter.hotendTemperatures[index] != 0) ? Math.round(connectedPrinter.hotendTemperatures[index]) + "°C" : ""
                                }
                                color: UM.Theme.getColor("text")
                                font: UM.Theme.getFont("large")
                                anchors.left: extruderName.right
                                anchors.margins: UM.Theme.getSize("default_margin").width

                                MouseArea //For tooltip.
                                {
                                    id: extruderTemperatureTooltipArea
                                    hoverEnabled: true
                                    anchors.fill: parent
                                    onHoveredChanged:
                                    {
                                        if (containsMouse)
                                        {
                                            base.showTooltip(
                                                base,
                                                {x: 0, y: parent.mapToItem(base, 0, -parent.height / 4).y},
                                                catalog.i18nc("@tooltip", "The current temperature of this extruder.")
                                            );
                                        }
                                        else
                                        {
                                            base.hideTooltip();
                                        }
                                    }
                                }
                            }



                            Label //Extruder target temperature.
                            {
                                id: extruderTargetTemperature
                                Layout.row: 1
                                Layout.column: 3

                                text:
                                {
                                    if( index == 0)
                                        (connectedPrinter != null && connectedPrinter.hotendIds[index] != null && connectedPrinter.targetHotendTemperatures[index] != null && connectedPrinter.targetHotendTemperatures[index] != 0 ) ? Math.round(connectedPrinter.targetHotendTemperatures[index]) + "°C" : ""
                                    else
                                        (connectedPrinter != null && connectedPrinter.targetHotendTemperatures[index] != null && connectedPrinter.targetHotendTemperatures[index] != 0 ) ? Math.round(connectedPrinter.targetHotendTemperatures[index]) + "°C" : ""
                                }
                                font: UM.Theme.getFont("small")
                                color: UM.Theme.getColor("text_inactive")
                                anchors.left: extruderTemperature.right
                                anchors.margins: UM.Theme.getSize("default_margin").width

                                MouseArea //For tooltip.
                                {
                                    id: extruderTargetTemperatureTooltipArea
                                    hoverEnabled: true
                                    anchors.fill: parent
                                    onHoveredChanged:
                                    {
                                        if (containsMouse)
                                        {
                                            base.showTooltip(
                                                base,
                                                {x: 0, y: parent.mapToItem(base, 0, -parent.height / 4).y},
                                                catalog.i18nc("@tooltip", "The target hot end temperature of this extruder.")
                                            );
                                        }
                                        else
                                        {
                                            base.hideTooltip();
                                        }
                                    }
                                }
                            }

                            Rectangle //Material colour indication.
                            {
                                id: materialColor
                                Layout.row: 1
                                Layout.column: 3

                                width: materialName.height * 0.75
                                height: materialName.height * 0.75
                                color: (connectedPrinter != null && connectedPrinter.materialColors[index] != null && connectedPrinter.materialIds[index] != "") ? connectedPrinter.materialColors[index] : "#00000000"
                                border.width: UM.Theme.getSize("default_lining").width
                                border.color: UM.Theme.getColor("lining")
                                visible: connectedPrinter != null && connectedPrinter.materialColors[index] != null && connectedPrinter.materialIds[index] != ""
                                //anchors.left: parent.left
                                //anchors.leftMargin: UM.Theme.getSize("default_margin").width
                                //anchors.verticalCenter: materialName.verticalCenter
                                anchors.left: extruderTargetTemperature.right
                                anchors.margins: UM.Theme.getSize("default_margin").width

                                MouseArea //For tooltip.
                                {
                                    id: materialColorTooltipArea
                                    hoverEnabled: true
                                    anchors.fill: parent
                                    onHoveredChanged:
                                    {
                                        if (containsMouse)
                                        {
                                            base.showTooltip(
                                                base,
                                                {x: 0, y: parent.mapToItem(base, 0, -parent.height / 2).y},
                                                catalog.i18nc("@tooltip", "The colour of the material in this extruder.")
                                            );
                                        }
                                        else
                                        {
                                            base.hideTooltip();
                                        }
                                    }
                                }
                            }
                            Label //Material name.
                            {
                                id: materialName
                                Layout.row: 1
                                Layout.column: 4

                                text: (connectedPrinter != null && connectedPrinter.materialNames[index] != null && connectedPrinter.materialIds[index] != "") ? connectedPrinter.materialNames[index] : ""
                                font: UM.Theme.getFont("default")
                                color: UM.Theme.getColor("text")
                                anchors.left: materialColor.right
                                anchors.margins: UM.Theme.getSize("default_margin").width

                                MouseArea //For tooltip.
                                {
                                    id: materialNameTooltipArea
                                    hoverEnabled: true
                                    anchors.fill: parent
                                    onHoveredChanged:
                                    {
                                        if (containsMouse)
                                        {
                                            base.showTooltip(
                                                base,
                                                {x: 0, y: parent.mapToItem(base, 0, 0).y},
                                                catalog.i18nc("@tooltip", "The material in this extruder.")
                                            );
                                        }
                                        else
                                        {
                                            base.hideTooltip();
                                        }
                                    }
                                }
                            }
                            Label //Variant name.
                            {
                                id: variantName
                                Layout.row: 1
                                Layout.column: 5

                                text: (connectedPrinter != null && connectedPrinter.hotendIds[index] != null) ? connectedPrinter.hotendIds[index] : ""
                                font: UM.Theme.getFont("default")
                                color: UM.Theme.getColor("text")
                                anchors.left: materialName.right
                                anchors.margins: UM.Theme.getSize("default_margin").width

                                MouseArea //For tooltip.
                                {
                                    id: variantNameTooltipArea
                                    hoverEnabled: true
                                    anchors.fill: parent
                                    onHoveredChanged:
                                    {
                                        if (containsMouse)
                                        {
                                            base.showTooltip(
                                                base,
                                                {x: 0, y: parent.mapToItem(base, 0, -parent.height / 4).y},
                                                catalog.i18nc("@tooltip", "The nozzle inserted in this extruder.")
                                            );
                                        }
                                        else
                                        {
                                            base.hideTooltip();
                                        }
                                    }
                                }
                            }

                            // ROW 2

                            TextField
                            {
                                id: temperatureTextField_1
                                Layout.row: 2
                                Layout.column: 1

                                readOnly: false
                                text: ""

                                width: parent.width / 2
                                validator: IntValidator
                                {
                                    bottom: 1
                                    top: 300
                                }
                            }

                            Button
                            {
                                Layout.row: 2
                                Layout.column: 2

                                text: "Pre-heat"
                                width: parent.width / 2

                                onClicked:
                                {
                                    if( connectedPrinter != null )
                                    {
                                        if( temperatureTextField_1.text == "" )
                                        {
                                             connectedPrinter.preheatHotend( index )

                                            if( index == 0)
                                                temperatureTextField_1.text = (connectedPrinter != null && connectedPrinter.hotendIds[index] != null && connectedPrinter.targetHotendTemperatures[index] != null && connectedPrinter.targetHotendTemperatures[index] != 0 ) ? Math.round(connectedPrinter.targetHotendTemperatures[index]) + "°C" : ""
                                            else
                                                temperatureTextField_1.text = (connectedPrinter != null && connectedPrinter.targetHotendTemperatures[index] != null && connectedPrinter.targetHotendTemperatures[index] != 0 ) ? Math.round(connectedPrinter.targetHotendTemperatures[index]) + "°C" : ""
                                        }
                                        else
                                        {
                                            connectedPrinter.setTargetHotendTemperature(index, parseInt(temperatureTextField_1.text))

                                            if( temperatureTextField_1.text.indexOf("°C") == -1 )
                                                temperatureTextField_1.text += "°C"
                                        }
                                    }
                                }

                                style:   ButtonStyle
                                {
                                    background: Rectangle
                                    {
                                        radius: 4
                                        border.width: UM.Theme.getSize("default_lining").width
                                        border.color:
                                        {
                                            if(!control.enabled)
                                                return UM.Theme.getColor("action_button_disabled_border");
                                            else if(control.pressed)
                                                return UM.Theme.getColor("action_button_active_border");
                                            else if(control.hovered)
                                                return UM.Theme.getColor("action_button_hovered_border");
                                            else
                                                return UM.Theme.getColor("action_button_border");
                                        }
                                        color:
                                        {
                                            if(!control.enabled)
                                                //return UM.Theme.getColor("button_disabled");
                                                return UM.Theme.getColor("button_disabled_lighter");
                                            else if(control.pressed)
                                                return UM.Theme.getColor("button_active");
                                            else if(control.hovered)
                                                return UM.Theme.getColor("button_hover");
                                            else
                                                return UM.Theme.getColor("button");
                                        }
                                        //Behavior on color { ColorAnimation { duration: 50; } }

                                        implicitWidth: actualLabel.contentWidth + (UM.Theme.getSize("default_margin").width * 2)
                                        implicitHeight: actualLabel.contentHeight + (UM.Theme.getSize("default_margin").height/2)

                                        Label
                                        {
                                            id: actualLabel
                                            anchors.centerIn: parent
                                            color:
                                            {
                                                if(!control.enabled)
                                                    return UM.Theme.getColor("button_disabled_text");
                                                else
                                                    return UM.Theme.getColor("button_text");
                                            }
                                            font: UM.Theme.getFont("small")
                                            text: control.text
                                        }
                                    }
                                    label: Item { }
                                }
                            }

                        } // GridLayout

                    }//delegate
	            }
	        }
	    }

	    Rectangle
	    {
	        color: UM.Theme.getColor("sidebar_lining")
	        width: parent.width
	        height: UM.Theme.getSize("sidebar_lining_thin").width
	    }

	    Rectangle
	    {
	        color: UM.Theme.getColor("sidebar")
	        width: parent.width
	        height: machineHeatedBed.properties.value == "True" ? UM.Theme.getSize("sidebar_extruder_box").height : 0
	        visible: machineHeatedBed.properties.value == "True"

	        Label //Build plate label.
	        {
	            text: catalog.i18nc("@label", "Build plate")
	            font: UM.Theme.getFont("default")
	            color: UM.Theme.getColor("text")
	            anchors.left: parent.left
	            anchors.top: parent.top
	            anchors.margins: UM.Theme.getSize("default_margin").width
	        }
            Label //Bed target temperature.
	        {
	            id: bedTargetTemperature
                text: (connectedPrinter != null && connectedPrinter.targetBedTemperature != 0) ? connectedPrinter.targetBedTemperature + "°C" : ""
	            font: UM.Theme.getFont("small")
	            color: UM.Theme.getColor("text_inactive")
	            anchors.right: parent.right
	            anchors.rightMargin: UM.Theme.getSize("default_margin").width
	            anchors.bottom: bedCurrentTemperature.bottom

	            MouseArea //For tooltip.
	            {
	                id: bedTargetTemperatureTooltipArea
	                hoverEnabled: true
	                anchors.fill: parent
	                onHoveredChanged:
	                {
	                    if (containsMouse)
	                    {
	                        base.showTooltip(
	                            base,
	                            {x: 0, y: bedTargetTemperature.mapToItem(base, 0, -parent.height / 4).y},
	                            catalog.i18nc("@tooltip", "The target temperature of the heated bed. The bed will heat up or cool down towards this temperature. If this is 0, the bed heating is turned off.")
	                        );
	                    }
	                    else
	                    {
	                        base.hideTooltip();
	                    }
	                }
	            }
	        }
            Label //Current bed temperature.
	        {
	            id: bedCurrentTemperature
	            text: connectedPrinter != null ? Math.round(connectedPrinter.bedTemperature) + "°C" : ""
	            font: UM.Theme.getFont("large")
	            color: UM.Theme.getColor("text")
	            anchors.right: bedTargetTemperature.left
	            anchors.top: parent.top
	            anchors.margins: UM.Theme.getSize("default_margin").width

	            MouseArea //For tooltip.
	            {
	                id: bedTemperatureTooltipArea
	                hoverEnabled: true
	                anchors.fill: parent
	                onHoveredChanged:
	                {
	                    if (containsMouse)
	                    {
	                        base.showTooltip(
	                            base,
	                            {x: 0, y: bedCurrentTemperature.mapToItem(base, 0, -parent.height / 4).y},
	                            catalog.i18nc("@tooltip", "The current temperature of the heated bed.")
	                        );
	                    }
	                    else
	                    {
	                        base.hideTooltip();
	                    }
	                }
	            }
	        }
	        Rectangle //Input field for pre-heat temperature.
	        {
	            id: preheatTemperatureControl
	            color: !enabled ? UM.Theme.getColor("setting_control_disabled") : UM.Theme.getColor("setting_validation_ok")
	            enabled:
	            {
	                if (connectedPrinter == null)
	                {
	                    return false; //Can't preheat if not connected.
	                }
	                if (!connectedPrinter.acceptsCommands)
	                {
	                    return false; //Not allowed to do anything.
	                }
	                if (connectedPrinter.jobState == "printing" || connectedPrinter.jobState == "pre_print" || connectedPrinter.jobState == "resuming" || connectedPrinter.jobState == "pausing" || connectedPrinter.jobState == "paused" || connectedPrinter.jobState == "error" || connectedPrinter.jobState == "offline")
	                {
	                    return false; //Printer is in a state where it can't react to pre-heating.
	                }
	                return true;
	            }
	            border.width: UM.Theme.getSize("default_lining").width
	            border.color: !enabled ? UM.Theme.getColor("setting_control_disabled_border") : preheatTemperatureInputMouseArea.containsMouse ? UM.Theme.getColor("setting_control_border_highlight") : UM.Theme.getColor("setting_control_border")
	            anchors.left: parent.left
	            anchors.leftMargin: UM.Theme.getSize("default_margin").width
	            anchors.bottom: parent.bottom
	            anchors.bottomMargin: UM.Theme.getSize("default_margin").height
	            width: UM.Theme.getSize("setting_control").width
	            height: UM.Theme.getSize("setting_control").height

	            Rectangle //Highlight of input field.
	            {
	                anchors.fill: parent
	                anchors.margins: UM.Theme.getSize("default_lining").width
	                color: UM.Theme.getColor("setting_control_highlight")
	                opacity: preheatTemperatureControl.hovered ? 1.0 : 0
	            }
	            Label //Maximum temperature indication.
	            {
                    text: (bedTemperature.properties.maximum_value != "None" ? bedTemperature.properties.maximum_value : "") + "°C"
	                color: UM.Theme.getColor("setting_unit")
	                font: UM.Theme.getFont("default")
	                anchors.right: parent.right
	                anchors.rightMargin: UM.Theme.getSize("setting_unit_margin").width
	                anchors.verticalCenter: parent.verticalCenter
	            }
	            MouseArea //Change cursor on hovering.
	            {
	                id: preheatTemperatureInputMouseArea
	                hoverEnabled: true
	                anchors.fill: parent
	                cursorShape: Qt.IBeamCursor

	                onHoveredChanged:
	                {
	                    if (containsMouse)
	                    {
	                        base.showTooltip(
	                            base,
	                            {x: 0, y: preheatTemperatureInputMouseArea.mapToItem(base, 0, 0).y},
	                            catalog.i18nc("@tooltip of temperature input", "The temperature to pre-heat the bed to.")
	                        );
	                    }
	                    else
	                    {
	                        base.hideTooltip();
	                    }
	                }
	            }
	            TextInput
	            {
	                id: preheatTemperatureInput
	                font: UM.Theme.getFont("default")
	                color: !enabled ? UM.Theme.getColor("setting_control_disabled_text") : UM.Theme.getColor("setting_control_text")
	                selectByMouse: true
	                maximumLength: 10
	                enabled: parent.enabled
	                validator: RegExpValidator { regExp: /^-?[0-9]{0,9}[.,]?[0-9]{0,10}$/ } //Floating point regex.
	                anchors.left: parent.left
	                anchors.leftMargin: UM.Theme.getSize("setting_unit_margin").width
	                anchors.right: parent.right
	                anchors.verticalCenter: parent.verticalCenter

	                Component.onCompleted:
	                {
	                    if ((bedTemperature.resolve != "None" && bedTemperature.resolve) && (bedTemperature.stackLevels[0] != 0) && (bedTemperature.stackLevels[0] != 1))
	                    {
	                        // We have a resolve function. Indicates that the setting is not settable per extruder and that
	                        // we have to choose between the resolved value (default) and the global value
	                        // (if user has explicitly set this).
                            //text = bedTemperature.resolve;
                            text = "";
	                    }
	                    else
                        {
                            //text = bedTemperature.properties.value;
                            text = "";
	                    }
	                }
	            }
	        }

	        UM.RecolorImage
	        {
	            id: preheatCountdownIcon
	            width: UM.Theme.getSize("save_button_specs_icons").width
	            height: UM.Theme.getSize("save_button_specs_icons").height
	            sourceSize.width: width
	            sourceSize.height: height
	            color: UM.Theme.getColor("text")
	            visible: preheatCountdown.visible
	            source: UM.Theme.getIcon("print_time")
	            anchors.right: preheatCountdown.left
	            anchors.rightMargin: UM.Theme.getSize("default_margin").width / 2
	            anchors.verticalCenter: preheatCountdown.verticalCenter
	        }

	        Timer
	        {
	            id: preheatUpdateTimer
	            interval: 100 //Update every 100ms. You want to update every 1s, but then you have one timer for the updating running out of sync with the actual date timer and you might skip seconds.
	            running: connectedPrinter != null && connectedPrinter.preheatBedRemainingTime != ""
	            repeat: true
	            onTriggered: update()
	            property var endTime: new Date() //Set initial endTime to be the current date, so that the endTime has initially already passed and the timer text becomes invisible if you were to update.
	            function update()
	            {
	                preheatCountdown.text = ""
	                if (connectedPrinter != null)
	                {
	                    preheatCountdown.text = connectedPrinter.preheatBedRemainingTime;
	                }
	                if (preheatCountdown.text == "") //Either time elapsed or not connected.
	                {
	                    stop();
	                }
	            }
	        }
	        Label
	        {
	            id: preheatCountdown
	            text: connectedPrinter != null ? connectedPrinter.preheatBedRemainingTime : ""
	            visible: text != "" //Has no direct effect, but just so that we can link visibility of clock icon to visibility of the countdown text.
	            font: UM.Theme.getFont("default")
	            color: UM.Theme.getColor("text")
	            anchors.right: preheatButton.left
	            anchors.rightMargin: UM.Theme.getSize("default_margin").width
	            anchors.verticalCenter: preheatButton.verticalCenter
	        }

	        Button //The pre-heat button.
	        {
	            id: preheatButton
	            height: UM.Theme.getSize("setting_control").height
	            enabled:
	            {
	                if (!preheatTemperatureControl.enabled)
	                {
	                    return false; //Not connected, not authenticated or printer is busy.
	                }
	                if (preheatUpdateTimer.running)
	                {
	                    return true; //Can always cancel if the timer is running.
	                }
	                if (bedTemperature.properties.minimum_value != "None" && parseInt(preheatTemperatureInput.text) < parseInt(bedTemperature.properties.minimum_value))
	                {
	                    return false; //Target temperature too low.
	                }
	                if (bedTemperature.properties.maximum_value != "None" && parseInt(preheatTemperatureInput.text) > parseInt(bedTemperature.properties.maximum_value))
	                {
	                    return false; //Target temperature too high.
	                }
	                if (parseInt(preheatTemperatureInput.text) == 0)
	                {
	                    return false; //Setting the temperature to 0 is not allowed (since that cancels the pre-heating).
	                }
	                return true; //Preconditions are met.
	            }
	            anchors.right: parent.right
	            anchors.bottom: parent.bottom
	            anchors.margins: UM.Theme.getSize("default_margin").width

                style:   ButtonStyle
                {
                    background: Rectangle
                    {
                        radius: 4
                        border.width: UM.Theme.getSize("default_lining").width
                        border.color:
                        {
                            if(!control.enabled)
                                return UM.Theme.getColor("action_button_disabled_border");
                            else if(control.pressed)
                                return UM.Theme.getColor("action_button_active_border");
                            else if(control.hovered)
                                return UM.Theme.getColor("action_button_hovered_border");
                            else
                                return UM.Theme.getColor("action_button_border");
                        }
                        color:
                        {
                            if(!control.enabled)
                                //return UM.Theme.getColor("button_disabled");
                                return UM.Theme.getColor("button_disabled_lighter");
                            else if(control.pressed)
                                return UM.Theme.getColor("button_active");
                            else if(control.hovered)
                                return UM.Theme.getColor("button_hover");
                            else
                                return UM.Theme.getColor("button");
                        }
                        //Behavior on color { ColorAnimation { duration: 50; } }

                        implicitWidth: actualLabel.contentWidth + (UM.Theme.getSize("default_margin").width * 2)
                        implicitHeight: actualLabel.contentHeight + (UM.Theme.getSize("default_margin").height/2)

                        Label
                        {
                            id: actualLabel
                            anchors.centerIn: parent
                            color:
                            {
                                if(!control.enabled)
                                    return UM.Theme.getColor("button_disabled_text");
                                else
                                    return UM.Theme.getColor("button_text");
                            }
                            font: UM.Theme.getFont("small")
                            text: preheatUpdateTimer.running ? catalog.i18nc("@button Cancel pre-heating", "Cancel") : catalog.i18nc("@button", "Pre-heat")

                        }
                    }
                    label: Item { }
                }


	            onClicked:
	            {
	                if (!preheatUpdateTimer.running)
	                {
	                    connectedPrinter.preheatBed(preheatTemperatureInput.text, connectedPrinter.preheatBedTimeout);
	                    preheatUpdateTimer.start();
	                    preheatUpdateTimer.update(); //Update once before the first timer is triggered.
	                }
	                else
	                {
	                    connectedPrinter.cancelPreheatBed();
	                    preheatUpdateTimer.update();
	                }
	            }

	            onHoveredChanged:
	            {
	                if (hovered)
	                {
	                    base.showTooltip(
	                        base,
	                        {x: 0, y: preheatButton.mapToItem(base, 0, 0).y},
	                        catalog.i18nc("@tooltip of pre-heat", "Heat the bed in advance before printing. You can continue adjusting your print while it is heating, and you won't have to wait for the bed to heat up when you're ready to print.")
	                    );
	                }
	                else
	                {
	                    base.hideTooltip();
	                }
	            }
	        }
	    }

	 	Rectangle
	    {
	        color: UM.Theme.getColor("sidebar_lining")
	        width: parent.width
	        height: UM.Theme.getSize("sidebar_lining_thin").width
	    }

	    Rectangle
	    {
	        height: UM.Theme.getSize("default_margin").height
	        width: base.width
	        color: "transparent"
		}

	    Canvas
	    {
	        anchors.right: parent.right
	        height: width / 3
	        width: base.width - 8 * UM.Theme.getSize("default_margin").width

	        anchors.rightMargin: UM.Theme.getSize("default_margin").width*4
	        anchors.leftMargin: UM.Theme.getSize("default_margin").width*4

	        id: temperatureGraph

	        antialiasing: true

	        property variant nozzleTemperatureValues: [[]]
	        property variant bedTemperatureValues: []
	        property variant lineStyles: [Qt.rgba(1, 0, 0, 1), Qt.rgba(0, 1, 0, 1), Qt.rgba(1, 1, 0, 1), Qt.rgba(1, 0, 1, 1)]
	        property variant bedLineStyle: Qt.rgba(0, 0, 1, 1)

	        function updateValues()
	        {
	            var heatedBed = machineHeatedBed.properties.value == "True"
	            var graphs = machineExtruderCount.properties.value
	            var resolution = 60

	            while(nozzleTemperatureValues.length < graphs)
	            {
	                nozzleTemperatureValues.push([])
	            }

	            for(var i = 0; i < graphs; i++)
	            {
	                while(nozzleTemperatureValues[i].length < resolution)
	                {
	                    nozzleTemperatureValues[i].push(0)
	                }

	                for(var j = 0; j < resolution - 1; j++)
	                {
	                    nozzleTemperatureValues[i][j] = nozzleTemperatureValues[i][j + 1]
	                }
	                nozzleTemperatureValues[i][resolution - 1] = printerConnected ? Math.round(connectedPrinter.hotendTemperatures[i]) : 0
	            }

	            if(heatedBed)
	            {
	                while(bedTemperatureValues.length < resolution)
	                {
	                    bedTemperatureValues.push(0)
	                }

	                for(var j = 0; j < resolution - 1; j++)
	                {
	                    bedTemperatureValues[j] = bedTemperatureValues[j + 1]
	                }
	                bedTemperatureValues[resolution - 1] = printerConnected ? Math.round(connectedPrinter.bedTemperature) : 0
	            }

	            requestPaint()
	        }

	        onPaint: {
	            var ctx = temperatureGraph.getContext('2d');
	            ctx.save();
	            ctx.clearRect(0, 0, temperatureGraph.width, temperatureGraph.height);
	            ctx.translate(0,0);
	            ctx.lineWidth = 1;
	            //ctx.strokeStyle = Qt.rgba(.3, .3, .3, 1);
	            ctx.strokeStyle = Qt.rgba(.75, .84, .18, 1);

	            // Horizontal lines
	            for(var i = 0; i < 6; i++)
	            {
	                if(i > 0)
	                {
	                    ctx.beginPath();
	                    //ctx.moveTo(0, temperatureGraph.height / 6 * i);
	                    ctx.moveTo(temperatureGraph.width/12, temperatureGraph.height / 6 * i);
	                    ctx.lineTo(temperatureGraph.width, temperatureGraph.height / 6 * i);
	                    ctx.closePath();
	                    ctx.stroke();
	                }
	            }

	            // Very bottom line
	            ctx.beginPath();
	            ctx.moveTo(0, temperatureGraph.height-1);
	            ctx.lineTo(temperatureGraph.width, temperatureGraph.height-1);
	            ctx.closePath();
	            ctx.stroke();

	            // Very top line
	            ctx.beginPath();
	            ctx.moveTo(0, 1);
	            ctx.lineTo(temperatureGraph.width, 1);
	            ctx.closePath();
	            ctx.stroke();

	            // Vertical lineStyles
	            for(var i = 0; i < 12; i++)
	            {
	                if(i > 0 )
	                {
	                    ctx.beginPath();
	                    ctx.moveTo(temperatureGraph.width / 12 * i, 0);
	                    ctx.lineTo(temperatureGraph.width / 12 * i, temperatureGraph.height);
	                    ctx.closePath();
	                    ctx.stroke();
	                }

	                else
	                {
	                    ctx.beginPath();
	                    ctx.moveTo(0, 0);
	                    ctx.lineTo(0, temperatureGraph.height);
	                    ctx.closePath();
	                    ctx.stroke();
	                }
	            }

	            // Vertical ver right lineStyles
	            ctx.beginPath();
	            ctx.moveTo(temperatureGraph.width - 1, 0);
	            ctx.lineTo(temperatureGraph.width - 1, temperatureGraph.height);
	            ctx.closePath();
	            ctx.stroke();


	            for(var k = 0; k < nozzleTemperatureValues.length; k++)
	            {
	                ctx.strokeStyle = lineStyles[k];

	                ctx.beginPath();
	                //ctx.moveTo(0, temperatureGraph.height + 1);
	                ctx.moveTo(0, temperatureGraph.height + 2);
	                for(var i = 0; i < nozzleTemperatureValues[k].length; i++)
	                {
	                    ctx.lineTo(i * temperatureGraph.width / (nozzleTemperatureValues[k].length - 1), temperatureGraph.height - nozzleTemperatureValues[k][i] / 300 * temperatureGraph.height);
	                }
	                //ctx.lineTo(temperatureGraph.width, temperatureGraph.height + 1);
	                ctx.lineTo(temperatureGraph.width, temperatureGraph.height + 2);
	                ctx.closePath();
	                ctx.stroke();
	            }

	            ctx.strokeStyle = bedLineStyle;

	            ctx.beginPath();
	            ctx.moveTo(0, temperatureGraph.height + 1);
	            for(var i = 0; i < bedTemperatureValues.length; i++)
	            {
	                ctx.lineTo(i * temperatureGraph.width / (bedTemperatureValues.length - 1), temperatureGraph.height - bedTemperatureValues[i] / 300 * temperatureGraph.height);
	            }
	            ctx.lineTo(temperatureGraph.width, temperatureGraph.height + 1);
	            ctx.closePath();
	            ctx.stroke();

	            ctx.fillStyle = Qt.rgba(0, 0, 0, 1);
	            ctx.fillText( 0, 2, temperatureGraph.height - 3)
	            for(var i = 0; i < 5; i++)
	            {
	                ctx.fillText((5-i) * 50, 2, temperatureGraph.height / 6 * (i+1))
	            }

	            ctx.restore();
	        }
	 	}

	 	Rectangle
	    {
	        height: UM.Theme.getSize("default_margin").height
	        width: base.width
	        color: "transparent"
		}

	    UM.SettingPropertyProvider
	    {
	        id: bedTemperature
	        containerStackId: Cura.MachineManager.activeMachineId
	        key: "material_bed_temperature"
	        watchedProperties: ["value", "minimum_value", "maximum_value", "resolve"]
	        storeIndex: 0

	        property var resolve: Cura.MachineManager.activeStackId != Cura.MachineManager.activeMachineId ? properties.resolve : "None"
	    }

        UM.SettingPropertyProvider
        {
            id: hotendTemperature
            containerStackId: Cura.MachineManager.activeMachineId
            key: "material_bed_temperature"
            watchedProperties: ["value", "minimum_value", "maximum_value", "resolve"]
            storeIndex: 0

            property var resolve: Cura.MachineManager.activeStackId != Cura.MachineManager.activeMachineId ? properties.resolve : "None"
        }

	    UM.SettingPropertyProvider
	    {
	        id: machineExtruderCount
	        containerStackId: Cura.MachineManager.activeMachineId
	        key: "machine_extruder_count"
	        watchedProperties: ["value"]
	    }

	    Loader
	    {
	        sourceComponent: monitorSection
	        property string label: catalog.i18nc("@label", "Active print")
	    }
	    Loader
	    {
	        sourceComponent: monitorItem
	        property string label: catalog.i18nc("@label", "Job Name")
	        property string value: connectedPrinter != null ? connectedPrinter.jobName : ""
	    }
	    Loader
	    {
	        sourceComponent: monitorItem
	        property string label: catalog.i18nc("@label", "Printing Time")
	        property string value: connectedPrinter != null ? getPrettyTime(connectedPrinter.timeTotal) : ""
	    }
	    Loader
	    {
	        sourceComponent: monitorItem
	        property string label: catalog.i18nc("@label", "Estimated time left")
	        property string value: ((connectedPrinter != null) && (connectedPrinter.timeTotal != 0)) ? getPrettyTime(connectedPrinter.timeTotal - connectedPrinter.timeElapsed) : getPrettyTime(0)
	    }
	    Loader
	    {
	        sourceComponent: monitorItem
	        property string label: catalog.i18nc("@label", "Final print time")
	        property string value: connectedPrinter != null ? getPrettyTime(connectedPrinter.timeElapsed) : ""
	    }

		Timer
		{
		    interval: 1000
		    running: true
		    repeat: true

            onTriggered: temperatureGraph.updateValues()
		}

		Loader
	    {
	        sourceComponent: monitorSection
	        property string label: catalog.i18nc("@label", "Manual control")
	    }
	    Loader
	    {
	        sourceComponent: monitorControls
	    }

	    function loadSection(label, path)
	    {
	        var title = Qt.createQmlObject('import QtQuick 2.2; Loader {property string label: ""}', printMonitor);
	        title.sourceComponent = monitorSection
	        title.label = label
	        var content = Qt.createQmlObject('import QtQuick 2.2; Loader {}', printMonitor);
            content.source = "file:///" + path
	        content.item.width = base.width - 2 * UM.Theme.getSize("default_margin").width
	    }

	    // Comands.qml loaded hear
	    Repeater
	    {
	        model: Printer.printMonitorAdditionalSections
	        delegate: Item
	        {
	            Component.onCompleted: printMonitor.loadSection(modelData["name"], modelData["path"])
	        }
		}

	    Component
	    {
	        id: monitorItem

	        Row
	        {
	            height: UM.Theme.getSize("setting_control").height
	            width: base.width - 2 * UM.Theme.getSize("default_margin").width
	            anchors.left: parent.left
	            anchors.leftMargin: UM.Theme.getSize("default_margin").width

	            Label
	            {
	                width: parent.width * 0.4
	                anchors.verticalCenter: parent.verticalCenter
	                text: label
	                color: connectedPrinter != null && connectedPrinter.acceptsCommands ? UM.Theme.getColor("setting_control_text") : UM.Theme.getColor("setting_control_disabled_text")
	                font: UM.Theme.getFont("default")
	                elide: Text.ElideRight
	            }
	            Label
	            {
	                width: parent.width * 0.6
	                anchors.verticalCenter: parent.verticalCenter
	                text: value
	                color: connectedPrinter != null && connectedPrinter.acceptsCommands ? UM.Theme.getColor("setting_control_text") : UM.Theme.getColor("setting_control_disabled_text")
	                font: UM.Theme.getFont("default")
	                elide: Text.ElideRight
	            }
	        }
	    }
	    Component
	    {
	        id: monitorSection

	        Rectangle
	        {
	            color: UM.Theme.getColor("setting_category")
	            width: base.width
	            height: UM.Theme.getSize("section").height

	            Label
	            {
	                anchors.verticalCenter: parent.verticalCenter
	                anchors.left: parent.left
	                anchors.leftMargin: UM.Theme.getSize("default_margin").width
	                text: label
	                font: UM.Theme.getFont("setting_category")
	                color: UM.Theme.getColor("setting_category_text")
	            }
	        }
	    }
	    Component
	    {
	        id: monitorControls

	        Item
	        {
	            width: base.width - 2 * UM.Theme.getSize("default_margin").width
	            height: childrenRect.height + 2 * UM.Theme.getSize("default_margin").width
	            anchors.left: parent.left
	            anchors.leftMargin: UM.Theme.getSize("default_margin").width

	            enabled: connectedPrinter

	            Row
	            {
	                id: baseControls

	                anchors.left: parent.left
	                anchors.top: parent.top
	                anchors.topMargin: UM.Theme.getSize("default_margin").width
	                spacing: UM.Theme.getSize("button_spacing").width

	                Button
	                {
	                    text: "Connect"
	                    onClicked:
	                    {
	                        connectedPrinter.connect()
                            connectedPrinter.errorFromPrinter.disconnect(printMonitor.receive)
                            connectedPrinter.errorFromPrinter.connect(printMonitor.receive)
	                    }

                        style:   ButtonStyle
                        {
                            background: Rectangle
                            {
                                radius: 4
                                border.width: UM.Theme.getSize("default_lining").width
                                border.color:
                                {
                                    if(!control.enabled)
                                        return UM.Theme.getColor("action_button_disabled_border");
                                    else if(control.pressed)
                                        return UM.Theme.getColor("action_button_active_border");
                                    else if(control.hovered)
                                        return UM.Theme.getColor("action_button_hovered_border");
                                    else
                                        return UM.Theme.getColor("action_button_border");
                                }
                                color:
                                {
                                    if(!control.enabled)
                                        //return UM.Theme.getColor("button_disabled");
                                        return UM.Theme.getColor("button_disabled_lighter");
                                    else if(control.pressed)
                                        return UM.Theme.getColor("button_active");
                                    else if(control.hovered)
                                        return UM.Theme.getColor("button_hover");
                                    else
                                        return UM.Theme.getColor("button");
                                }
                                //Behavior on color { ColorAnimation { duration: 50; } }

                                implicitWidth: actualLabel.contentWidth + (UM.Theme.getSize("default_margin").width * 2)
                                implicitHeight: actualLabel.contentHeight + (UM.Theme.getSize("default_margin").height/2)

                                Label
                                {
                                    id: actualLabel
                                    anchors.centerIn: parent
                                    color:
                                    {
                                        if(!control.enabled)
                                            return UM.Theme.getColor("button_disabled_text");
                                        else
                                            return UM.Theme.getColor("button_text");
                                    }
                                    font: UM.Theme.getFont("small")
                                    text: control.text
                                }
                            }
                            label: Item { }
                        }
	                }

	                Button
	                {
	                    text: "Disconnect"
	                    onClicked:
	                    {
	                        connectedPrinter.close()
	                    }
                        style:   ButtonStyle
                        {
                            background: Rectangle
                            {
                                radius: 4
                                border.width: UM.Theme.getSize("default_lining").width
                                border.color:
                                {
                                    if(!control.enabled)
                                        return UM.Theme.getColor("action_button_disabled_border");
                                    else if(control.pressed)
                                        return UM.Theme.getColor("action_button_active_border");
                                    else if(control.hovered)
                                        return UM.Theme.getColor("action_button_hovered_border");
                                    else
                                        return UM.Theme.getColor("action_button_border");
                                }
                                color:
                                {
                                    if(!control.enabled)
                                        //return UM.Theme.getColor("button_disabled");
                                        return UM.Theme.getColor("button_disabled_lighter");
                                    else if(control.pressed)
                                        return UM.Theme.getColor("button_active");
                                    else if(control.hovered)
                                        return UM.Theme.getColor("button_hover");
                                    else
                                        return UM.Theme.getColor("button");
                                }
                                //Behavior on color { ColorAnimation { duration: 50; } }

                                implicitWidth: actualLabel.contentWidth + (UM.Theme.getSize("default_margin").width * 2)
                                implicitHeight: actualLabel.contentHeight + (UM.Theme.getSize("default_margin").height/2)

                                Label
                                {
                                    id: actualLabel
                                    anchors.centerIn: parent
                                    color:
                                    {
                                        if(!control.enabled)
                                            return UM.Theme.getColor("button_disabled_text");
                                        else
                                            return UM.Theme.getColor("button_text");
                                    }
                                    font: UM.Theme.getFont("small")
                                    text: control.text
                                }
                            }
                            label: Item { }
                        }
	                 }

	                Button
	                {
	                    text: catalog.i18nc("@label", "Console")
	                    onClicked:
	                    {
	                        connectedPrinter.messageFromPrinter.disconnect(printer_control.receive)
	                        connectedPrinter.messageFromPrinter.connect(printer_control.receive)
	                        printer_control.visible = true;
	                    }
                        style:   ButtonStyle
                        {
                            background: Rectangle
                            {
                                radius: 4
                                border.width: UM.Theme.getSize("default_lining").width
                                border.color:
                                {
                                    if(!control.enabled)
                                        return UM.Theme.getColor("action_button_disabled_border");
                                    else if(control.pressed)
                                        return UM.Theme.getColor("action_button_active_border");
                                    else if(control.hovered)
                                        return UM.Theme.getColor("action_button_hovered_border");
                                    else
                                        return UM.Theme.getColor("action_button_border");
                                }
                                color:
                                {
                                    if(!control.enabled)
                                        //return UM.Theme.getColor("button_disabled");
                                        return UM.Theme.getColor("button_disabled_lighter");
                                    else if(control.pressed)
                                        return UM.Theme.getColor("button_active");
                                    else if(control.hovered)
                                        return UM.Theme.getColor("button_hover");
                                    else
                                        return UM.Theme.getColor("button");
                                }
                                //Behavior on color { ColorAnimation { duration: 50; } }

                                implicitWidth: actualLabel.contentWidth + (UM.Theme.getSize("default_margin").width * 2)
                                implicitHeight: actualLabel.contentHeight + (UM.Theme.getSize("default_margin").height/2)

                                Label
                                {
                                    id: actualLabel
                                    anchors.centerIn: parent
                                    color:
                                    {
                                        if(!control.enabled)
                                            return UM.Theme.getColor("button_disabled_text");
                                        else
                                            return UM.Theme.getColor("button_text");
                                    }
                                    font: UM.Theme.getFont("small")
                                    text: control.text
                                }
                            }
                            label: Item { }
                        }
	                }
	            }



	            Row
	            {
	                id: positionLabel

	                anchors.left: parent.left
	                anchors.leftMargin: parent.width/9
	                anchors.top: baseControls.bottom
	                anchors.topMargin: UM.Theme.getSize("default_margin").height
	                spacing: parent.width*5/18
	                width: parent.width

	                Label
	                {
	                    text: "Position"
	                    color: UM.Theme.getColor("setting_control_text")
	                    font: UM.Theme.getFont("default")
	                    width: parent.width/5
	                }

	                Label
	                {
	                    text: "Extrusion"
	                    color: UM.Theme.getColor("setting_control_text")
	                    font: UM.Theme.getFont("default")
	                    width: parent.width/3
	                }
	            }

	            //Column 1: Position: X/Y
	            Column
	            {
	                id: positionXYColumn

	                anchors.top: positionLabel.bottom
	                anchors.topMargin: UM.Theme.getSize("default_margin").width
	                anchors.leftMargin: UM.Theme.getSize("default_margin").width/2

	                width: childrenRect.width
	                height: childrenRect.height

	                spacing: 1

	                GridLayout
	                {
	                    id: controlsXYLayout
	                    columns: 3
	                    rows: 4
	                    rowSpacing: 1
	                    columnSpacing: 1

	                    anchors.leftMargin: 0
	                    anchors.left: parent.left

	                    Label
	                    {
	                        text: "X/Y"
	                        color: UM.Theme.getColor("setting_control_text")
	                        font: UM.Theme.getFont("default")
	                        width: parent.width
	                        Layout.row: 1
	                        Layout.column: 2
	                        Layout.preferredWidth: UM.Theme.getSize("section").height
	                        Layout.preferredHeight: UM.Theme.getSize("section").height
	                    }

	                    Button
	                    {
	                        //text: "/\\"
	                        Layout.row: 2
	                        Layout.column: 2
	                        Layout.preferredWidth: UM.Theme.getSize("section").height
	                        Layout.preferredHeight: UM.Theme.getSize("section").height
	                        iconSource: UM.Theme.getIcon("control_y_back");

	                        onClicked:
	                        {
	                            connectedPrinter.moveHead(0, -parseFloat(moveLengthTextField.text), 0)
	                        }
	                    }

	                    Button
	                    {
	                        //text: "<"
	                        Layout.row: 3
	                        Layout.column: 1
	                        Layout.preferredWidth: UM.Theme.getSize("section").height
	                        Layout.preferredHeight: UM.Theme.getSize("section").height
	                        iconSource: UM.Theme.getIcon("control_x_left");

	                        onClicked:
	                        {
	                            connectedPrinter.moveHead(-parseFloat(moveLengthTextField.text), 0, 0)
	                        }
	                    }

	                    Button
	                    {
	                        //text: ">"
	                        Layout.row: 3
	                        Layout.column: 3
	                        Layout.preferredWidth: UM.Theme.getSize("section").height
	                        Layout.preferredHeight: UM.Theme.getSize("section").height
	                        iconSource: UM.Theme.getIcon("control_x_right");

	                        onClicked:
	                        {
	                            connectedPrinter.moveHead(parseFloat(moveLengthTextField.text), 0, 0)
	                        }
	                    }

	                    Button
	                    {
	                        //text: "V"
	                        Layout.row: 4
	                        Layout.column: 2
	                        Layout.preferredWidth: UM.Theme.getSize("section").height
	                        Layout.preferredHeight: UM.Theme.getSize("section").height
	                        iconSource: UM.Theme.getIcon("control_y_forward");

	                        onClicked:
	                        {
	                            connectedPrinter.moveHead(0, parseFloat(moveLengthTextField.text), 0)
	                        }
	                    }

	                    Button
	                    {
	                        //text: "H"
	                        Layout.row: 3
	                        Layout.column: 2
	                        Layout.preferredWidth: UM.Theme.getSize("section").height
	                        Layout.preferredHeight: UM.Theme.getSize("section").height
	                        iconSource: UM.Theme.getIcon("xy_home");

	                        onClicked:
	                        {
                                connectedPrinter.homeXY()
	                        }
	                    }
	                }
	            }

	            Column
	            {
	                id: positionZColumn

	                anchors.left: positionXYColumn.right
	                anchors.leftMargin: UM.Theme.getSize("default_margin").width/2
	                anchors.top: positionXYColumn.top

	                width: childrenRect.width
	                height: childrenRect.height

	                spacing: 1

	                GridLayout
	                {
	                    id: controlsZLayout
	                    columns: 1
	                    rows: 4
	                    rowSpacing: 1
	                    columnSpacing: 1

	                    anchors.left: parent.left

	                    Label
	                    {
	                        text: "Z"
	                        color: UM.Theme.getColor("setting_control_text")
	                        font: UM.Theme.getFont("default")
	                        Layout.row: 1
	                        Layout.column: 1
	                        Layout.preferredWidth: UM.Theme.getSize("section").height
	                        Layout.preferredHeight: UM.Theme.getSize("section").height
	                        width: UM.Theme.getSize("section").height
	                    }

	                    Button
	                    {
	                        //text: "/\\"
	                        Layout.row: 2
	                        Layout.column: 1
	                        Layout.preferredWidth: UM.Theme.getSize("section").height
	                        Layout.preferredHeight: UM.Theme.getSize("section").height
	                        width: UM.Theme.getSize("section").height
	                        iconSource: UM.Theme.getIcon("control_z_up");

	                        onClicked:
	                        {
	                            connectedPrinter.moveHead(0, 0, parseFloat(moveLengthTextField.text))
	                        }
	                    }

	                    Button
	                    {
	                        //text: "Z"
	                        Layout.row: 3
	                        Layout.column: 1
	                        Layout.preferredWidth: UM.Theme.getSize("section").height
	                        Layout.preferredHeight: UM.Theme.getSize("section").height
	                        width: UM.Theme.getSize("section").height
	                        height: UM.Theme.getSize("section").height
	                        iconSource: UM.Theme.getIcon("z_home");
	                        //style: UM.Theme.styles.print_monitor_position_button

	                        onClicked:
	                        {
	                            connectedPrinter.homeBed()
	                        }
	                    }

	                    Button
	                    {
	                        //text: "V"
	                        Layout.row: 4
	                        Layout.column: 1
	                        Layout.preferredWidth: UM.Theme.getSize("section").height
	                        Layout.preferredHeight: UM.Theme.getSize("section").height
	                        width: UM.Theme.getSize("section").height
	                        iconSource: UM.Theme.getIcon("control_z_down");

	                        onClicked:
	                        {
	                            connectedPrinter.moveHead(0, 0, -parseFloat(moveLengthTextField.text))
	                        }
	                    }
	                }
	            }


	            Row
	            {
	                id: homeXRow

	                //anchors.left: positionXYColumn.right
	                anchors.leftMargin: UM.Theme.getSize("default_margin").width/2
	                anchors.top: positionXYColumn.bottom
	                anchors.topMargin: UM.Theme.getSize("default_margin").height/4

	                spacing: 4
	                width: parent.width

	                Label
	                {
                        text: "Home X:  "
	                    color: UM.Theme.getColor("setting_control_text")
	                    font: UM.Theme.getFont("default")

	                }

	                Button
	                {
	                    //text: "X"
	                    width: UM.Theme.getSize("section").height
	                    height: UM.Theme.getSize("section").height
	                    iconSource: UM.Theme.getIcon("x_home");

	                    onClicked:
	                    {
	                        connectedPrinter.homeX()
	                    }
	                }
	            }

	            Row
	            {
	                id: homeYRow

	                anchors.leftMargin: UM.Theme.getSize("default_margin").width/2
	                anchors.top: homeXRow.bottom
	                anchors.topMargin: UM.Theme.getSize("default_margin").height/4

	                spacing: 4
	                width: parent.width

	                Label
	                {
                        text: "Home Y:  "
	                    color: UM.Theme.getColor("setting_control_text")
	                    font: UM.Theme.getFont("default")
	                }

	                Button
	                {
	                    //text: "Y"
	                    width: UM.Theme.getSize("section").height
	                    height: UM.Theme.getSize("section").height
	                    iconSource: UM.Theme.getIcon("y_home");

	                    onClicked:
	                    {
	                        connectedPrinter.homeY()
	                    }
	                }

	            }

                Row
                {
                    id: homeAllRow

                    anchors.leftMargin: UM.Theme.getSize("default_margin").width/2
                    anchors.top: homeYRow.bottom
                    anchors.topMargin: UM.Theme.getSize("default_margin").height/4

                    spacing: 4
                    width: parent.width

                    Label
                    {
                        text: "Home All:"
                        color: UM.Theme.getColor("setting_control_text")
                        font: UM.Theme.getFont("default")
                    }

                    Button
                    {
                        //text: "Y"
                        width: UM.Theme.getSize("section").height
                        height: UM.Theme.getSize("section").height
                        iconSource: UM.Theme.getIcon("all_home");

                        onClicked:
                        {
                            connectedPrinter.homeHead()
                        }
                    }

                }


	            // Extrusion
	            Column
	            {
	                id: settingColumn

	                anchors.left: positionZColumn.right
	                anchors.leftMargin: UM.Theme.getSize("default_margin").width
	                anchors.top: positionZColumn.top

	                width: parent.width - positionXYColumn.width - positionZColumn.width - UM.Theme.getSize("default_margin").width * 2
	                height: childrenRect.height

	                spacing: 4

	                Row
	                {
	                    width: parent.width
	                    height: childrenRect.height

	                    Label
	                    {
	                        text: "Move length"
	                        color: UM.Theme.getColor("setting_control_text")
	                        font: UM.Theme.getFont("default")
	                        width: parent.width / 2
	                    }

	                    TextField
	                    {
	                        text: "1"
	                        id: moveLengthTextField
	                        width: parent.width / 2

	                        validator: DoubleValidator
	                        {
	                            bottom: 0
	                            top: 100
	                        }
	                    }
	                }

	                Row
	                {
	                    width: parent.width
	                    height: childrenRect.height

	                    Label
	                    {
	                        text: "Select extruder"
	                        color: UM.Theme.getColor("setting_control_text")
	                        font: UM.Theme.getFont("default")
	                        width: parent.width / 2
	                    }

	                    ComboBox
	                    {
	                        id: extruderSelector
	                        width: parent.width / 2

	                        model:
	                        {
	                            var l = []
	                            for(var i=0;i<machineExtruderCount.properties.value;i++)
	                            {
	                                l.push(i+1);
	                            }
	                            return l
	                        }

	                        onCurrentIndexChanged:
	                        {
                                if( connectedPrinter != null )
                                    connectedPrinter.setHotend(currentIndex)
	                        }
	                    }
	                }

	                Row
	                {
	                    width: parent.width
	                    height: childrenRect.height

	                    Label
	                    {
	                        text: "Extrusion amount"
	                        color: UM.Theme.getColor("setting_control_text")
	                        font: UM.Theme.getFont("default")
	                        width: parent.width / 2
	                    }

	                    TextField
	                    {
	                        text: "1"
	                        id: extrusionAmountTextField
	                        width: parent.width / 2
	                        validator: DoubleValidator
	                        {
	                            bottom: 0
	                            top: 10
	                        }
	                    }
	                }

	                Row
	                {
	                    width: parent.width
	                    height: childrenRect.height
	                    spacing: UM.Theme.getSize("button_spacing").width

	                    Button
	                    {
	                        text: "Extrude"
	                        width: parent.width / 2

	                        onClicked:
	                        {
	                            connectedPrinter.extrude(parseFloat(extrusionAmountTextField.text))
	                        }

                            style:   ButtonStyle
                            {
                                background: Rectangle
                                {
                                    radius: 4
                                    border.width: UM.Theme.getSize("default_lining").width
                                    border.color:
                                    {
                                        if(!control.enabled)
                                            return UM.Theme.getColor("action_button_disabled_border");
                                        else if(control.pressed)
                                            return UM.Theme.getColor("action_button_active_border");
                                        else if(control.hovered)
                                            return UM.Theme.getColor("action_button_hovered_border");
                                        else
                                            return UM.Theme.getColor("action_button_border");
                                    }
                                    color:
                                    {
                                        if(!control.enabled)
                                            //return UM.Theme.getColor("button_disabled");
                                            return UM.Theme.getColor("button_disabled_lighter");
                                        else if(control.pressed)
                                            return UM.Theme.getColor("button_active");
                                        else if(control.hovered)
                                            return UM.Theme.getColor("button_hover");
                                        else
                                            return UM.Theme.getColor("button");
                                    }
                                    //Behavior on color { ColorAnimation { duration: 50; } }

                                    implicitWidth: actualLabel.contentWidth + (UM.Theme.getSize("default_margin").width * 2)
                                    implicitHeight: actualLabel.contentHeight + (UM.Theme.getSize("default_margin").height/2)

                                    Label
                                    {
                                        id: actualLabel
                                        anchors.centerIn: parent
                                        color:
                                        {
                                            if(!control.enabled)
                                                return UM.Theme.getColor("button_disabled_text");
                                            else
                                                return UM.Theme.getColor("button_text");
                                        }
                                        font: UM.Theme.getFont("small")
                                        text: control.text
                                    }
                                }
                                label: Item { }
                            }
	                    }

	                    Button
	                    {
	                        text: "Retract"
	                        width: parent.width / 2

	                        onClicked:
	                        {
	                            connectedPrinter.extrude(-parseFloat(extrusionAmountTextField.text))
	                        }

                            style:   ButtonStyle
                            {
                                background: Rectangle
                                {
                                    radius: 4
                                    border.width: UM.Theme.getSize("default_lining").width
                                    border.color:
                                    {
                                        if(!control.enabled)
                                            return UM.Theme.getColor("action_button_disabled_border");
                                        else if(control.pressed)
                                            return UM.Theme.getColor("action_button_active_border");
                                        else if(control.hovered)
                                            return UM.Theme.getColor("action_button_hovered_border");
                                        else
                                            return UM.Theme.getColor("action_button_border");
                                    }
                                    color:
                                    {
                                        if(!control.enabled)
                                            //return UM.Theme.getColor("button_disabled");
                                            return UM.Theme.getColor("button_disabled_lighter");
                                        else if(control.pressed)
                                            return UM.Theme.getColor("button_active");
                                        else if(control.hovered)
                                            return UM.Theme.getColor("button_hover");
                                        else
                                            return UM.Theme.getColor("button");
                                    }
                                    //Behavior on color { ColorAnimation { duration: 50; } }

                                    implicitWidth: actualLabel.contentWidth + (UM.Theme.getSize("default_margin").width * 2)
                                    implicitHeight: actualLabel.contentHeight + (UM.Theme.getSize("default_margin").height/2)

                                    Label
                                    {
                                        id: actualLabel
                                        anchors.centerIn: parent
                                        color:
                                        {
                                            if(!control.enabled)
                                                return UM.Theme.getColor("button_disabled_text");
                                            else
                                                return UM.Theme.getColor("button_text");
                                        }
                                        font: UM.Theme.getFont("small")
                                        text: control.text
                                    }
                                }
                                label: Item { }
                            }
	                    }
	                }

	                Row
	                {
	                    width: parent.width
	                    height: childrenRect.height

	                    Label
	                    {
	                        text: "Select temperature"
	                        color: UM.Theme.getColor("setting_control_text")
	                        font: UM.Theme.getFont("default")
	                        width: parent.width / 2
	                    }

	                    TextField
	                    {
                            text: "1"
	                        id: temperatureTextField
	                        width: parent.width / 2
	                        validator: IntValidator
	                        {
                                bottom: 1
	                            top: 300
	                        }
	                    }
	                }

	                Row
	                {
	                    width: parent.width
	                    height: childrenRect.height
	                    spacing: UM.Theme.getSize("button_spacing").width

	                    Button
	                    {
	                        text: "Heat extruder"
	                        width: parent.width / 2

	                        onClicked:
	                        {
                                connectedPrinter.setTargetHotendTemperature(extruderSelector.currentIndex, parseInt(temperatureTextField.text))
	                        }

                            style:   ButtonStyle
                            {
                                background: Rectangle
                                {
                                    radius: 4
                                    border.width: UM.Theme.getSize("default_lining").width
                                    border.color:
                                    {
                                        if(!control.enabled)
                                            return UM.Theme.getColor("action_button_disabled_border");
                                        else if(control.pressed)
                                            return UM.Theme.getColor("action_button_active_border");
                                        else if(control.hovered)
                                            return UM.Theme.getColor("action_button_hovered_border");
                                        else
                                            return UM.Theme.getColor("action_button_border");
                                    }
                                    color:
                                    {
                                        if(!control.enabled)
                                            //return UM.Theme.getColor("button_disabled");
                                            return UM.Theme.getColor("button_disabled_lighter");
                                        else if(control.pressed)
                                            return UM.Theme.getColor("button_active");
                                        else if(control.hovered)
                                            return UM.Theme.getColor("button_hover");
                                        else
                                            return UM.Theme.getColor("button");
                                    }
                                    //Behavior on color { ColorAnimation { duration: 50; } }

                                    implicitWidth: actualLabel.contentWidth + (UM.Theme.getSize("default_margin").width * 2)
                                    implicitHeight: actualLabel.contentHeight + (UM.Theme.getSize("default_margin").height/2)

                                    Label
                                    {
                                        id: actualLabel
                                        anchors.centerIn: parent
                                        color:
                                        {
                                            if(!control.enabled)
                                                return UM.Theme.getColor("button_disabled_text");
                                            else
                                                return UM.Theme.getColor("button_text");
                                        }
                                        font: UM.Theme.getFont("small")
                                        text: control.text
                                    }
                                }
                                label: Item { }
                            }
	                    }

	                    Button
	                    {
	                        text: "Heat bed"
	                        width: parent.width / 2

	                        onClicked:
	                        {
	                            connectedPrinter.setTargetBedTemperature(parseInt(temperatureTextField.text))
	                        }

                            style:   ButtonStyle
                            {
                                background: Rectangle
                                {
                                    radius: 4
                                    border.width: UM.Theme.getSize("default_lining").width
                                    border.color:
                                    {
                                        if(!control.enabled)
                                            return UM.Theme.getColor("action_button_disabled_border");
                                        else if(control.pressed)
                                            return UM.Theme.getColor("action_button_active_border");
                                        else if(control.hovered)
                                            return UM.Theme.getColor("action_button_hovered_border");
                                        else
                                            return UM.Theme.getColor("action_button_border");
                                    }
                                    color:
                                    {
                                        if(!control.enabled)
                                            //return UM.Theme.getColor("button_disabled");
                                            return UM.Theme.getColor("button_disabled_lighter");
                                        else if(control.pressed)
                                            return UM.Theme.getColor("button_active");
                                        else if(control.hovered)
                                            return UM.Theme.getColor("button_hover");
                                        else
                                            return UM.Theme.getColor("button");
                                    }
                                    //Behavior on color { ColorAnimation { duration: 50; } }

                                    implicitWidth: actualLabel.contentWidth + (UM.Theme.getSize("default_margin").width * 2)
                                    implicitHeight: actualLabel.contentHeight + (UM.Theme.getSize("default_margin").height/2)

                                    Label
                                    {
                                        id: actualLabel
                                        anchors.centerIn: parent
                                        color:
                                        {
                                            if(!control.enabled)
                                                return UM.Theme.getColor("button_disabled_text");
                                            else
                                                return UM.Theme.getColor("button_text");
                                        }
                                        font: UM.Theme.getFont("small")
                                        text: control.text
                                    }
                                }
                                label: Item { }
                            }
	                    }
	                }
	            }
	        }
	    }
	    PrinterControlWindow
	    {
	        id: printer_control
	        onCommand:
	        {
	            if (!Cura.USBPrinterManager.sendCommandToCurrentPrinter(command))
	            {
	                receive("Error: Printer not connected")
	            }
	        }
		}

        MessageDialog
        {
            id: message_dialog
            title: catalog.i18nc("@window:title", "Error");
            standardButtons: StandardButton.Ok
            modality: Qt.ApplicationModal
        }
	}
}
