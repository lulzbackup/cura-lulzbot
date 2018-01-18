import QtQuick 2.2
import QtQuick.Controls 1.1
import QtQuick.Controls.Styles 1.1
import QtQuick.Layouts 1.1

import UM 1.2 as UM
import Cura 1.0 as Cura

Item
{
    property var connectedPrinter: printerConnected ? Cura.MachineManager.printerOutputDevices[0] : null
    width: 410
    height: 120
    enabled: connectedPrinter


    GridLayout
    {
        id: gridLayout
        columns: 2
        rows: 4
        rowSpacing: 1
        columnSpacing: 10
        anchors.fill: parent
        anchors.centerIn: parent
        anchors.leftMargin: 65
        anchors.rightMargin: 65

        Label
        {
            text: "Z-Offset value on EEPROM:"
            color: UM.Theme.getColor("setting_control_text")
            font: UM.Theme.getFont("default")
            Layout.row: 1
            Layout.column: 1
            Layout.preferredWidth: parent.width/3 - gridLayout.rowSpacing*3
            Layout.preferredHeight: UM.Theme.getSize("section").height
        }

        Label
        {
            text: "0"
            id: zOffsetValueEEPROM
            color: UM.Theme.getColor("setting_control_text")
            font: UM.Theme.getFont("default")
            Layout.row: 1
            Layout.column: 2
            Layout.preferredWidth: parent.width/3 - gridLayout.columnSpacing*3
            Layout.preferredHeight: UM.Theme.getSize("section").height
        }


        Label
        {
            text: "Current Z-Offset value:"
            color: UM.Theme.getColor("setting_control_text")
            font: UM.Theme.getFont("default")
            Layout.row: 2
            Layout.column: 1
            Layout.preferredWidth: parent.width/3 - gridLayout.rowSpacing*3
            Layout.preferredHeight: UM.Theme.getSize("section").height
        }

        Label
        {
            text: "0"
            id: zOffsetValueMemory
            color: UM.Theme.getColor("setting_control_text")
            font: UM.Theme.getFont("default")
            Layout.row: 2
            Layout.column: 2
            Layout.preferredWidth: parent.width/3 - gridLayout.columnSpacing*3
            Layout.preferredHeight: UM.Theme.getSize("section").height
        }

        Label
        {
            text: "Set new Z-Offset value:"
            color: UM.Theme.getColor("setting_control_text")
            font: UM.Theme.getFont("default")
            Layout.row: 3
            Layout.column: 1
            Layout.preferredWidth: parent.width/3 - gridLayout.columnSpacing*3
            Layout.preferredHeight: UM.Theme.getSize("section").height
        }

        UM.TooltipArea {
            Layout.row: 3
            Layout.column: 2
            height: childrenRect.height
            text: catalog.i18nc("@info:tooltip","Valid values are between -1.55 and -0.80")

            TextField
            {
                text: ""
                property color backgroundColor: "white"
                id: zOffsetTextField
                Layout.preferredWidth: parent.width/3 - gridLayout.columnSpacing*3
                Layout.preferredHeight: UM.Theme.getSize("section").height

                style: TextFieldStyle
                {
                    id: styleTF
                    textColor: "black"
                    background: Rectangle
                    {
                        id: rect
                        radius: 2
                        color: zOffsetTextField.backgroundColor
                        implicitWidth: 100
                        implicitHeight: UM.Theme.getSize("section").height*0.88
                        border.width: UM.Theme.getSize("default_lining").width
                        border.color: !enabled ? UM.Theme.getColor("setting_control_disabled_border") : UM.Theme.getColor("setting_control_border")
                    }
                }

                validator: DoubleValidator
                {   bottom: -1.55;
                    top: -0.80;
                    decimals: 2;
                    notation: DoubleValidator.StandardNotation
                }
            }
        }

        CheckBox {
            id: saveToFlashMemory
            Layout.row: 4
            Layout.column: 1
            checked: false
            style:
            CheckBoxStyle
            {
                label:
                    Label
                    {
                        color: UM.Theme.getColor("setting_control_text")
                        text: "Save Z-Offset to EEPROM"
                    }
            }
            visible: true
            enabled: UM.Preferences.getValue( "general/zoffsetSaveToFlashEnabled" )
        }

        Button
        {
            text: "Save"
            id: saveButton
            Layout.row: 4
            Layout.column: 2
            Layout.preferredWidth: parent.width/3 - gridLayout.columnSpacing*3
            Layout.preferredHeight: UM.Theme.getSize("section").height


            onClicked:
            {
                if( zOffsetTextField.acceptableInput )
                {
                    var value = parseFloat( zOffsetTextField.text )

                    if( (value >= -1.40) && (value <= -1.05) )
                    {
                        zOffsetTextField.backgroundColor = "white"
                        zOffsetValueMemory.text = zOffsetTextField.text
                        connectedPrinter.setZOffset( value, saveToFlashMemory.checked )
                        if( saveToFlashMemory.checked == true )
                            zOffsetValueEEPROM.text = zOffsetTextField.text
                    }
                    else if(  ((value <=-0.80) && (value >= -1.049) ) || ((value >= -1.55) && (value <= -1.401)) )
                    {
                        zOffsetTextField.backgroundColor = "yellow"
                        zOffsetValueMemory.text = zOffsetTextField.text
                        connectedPrinter.setZOffset( value, saveToFlashMemory.checked )
                        if( saveToFlashMemory.checked == true )
                            zOffsetValueEEPROM.text = zOffsetTextField.text
                    }
                    else
                        zOffsetTextField.backgroundColor = "red"

                }
                else
                {
                    zOffsetTextField.backgroundColor = "red"
                }
            }

            style: ButtonStyle
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


    Timer
    {
        id: timerValuesUpdates
        interval: 500
        running: true
        repeat: true

        onTriggered:
        {
            saveToFlashMemory.enabled = UM.Preferences.getValue( "general/zoffsetSaveToFlashEnabled" )

            if( saveToFlashMemory.enabled == false )
                saveToFlashMemory.checked = false

            if( (connectedPrinter != null) && (connectedPrinter.getZOffset() != undefined) && (zOffsetValueMemory.text == "0") )
            {
                zOffsetValueMemory.text = connectedPrinter.getZOffset()
                zOffsetValueEEPROM.text = connectedPrinter.getZOffset()
            }
        }
    }
}
