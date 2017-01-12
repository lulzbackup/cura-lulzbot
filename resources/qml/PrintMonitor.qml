// Copyright (c) 2016 Ultimaker B.V.
// Cura is released under the terms of the AGPLv3 or higher.

import QtQuick 2.2
import QtQuick.Controls 1.1
import QtQuick.Controls.Styles 1.1
import QtQuick.Layouts 1.1

import UM 1.2 as UM
import Cura 1.0 as Cura

Column
{
    id: printMonitor
    property var connectedPrinter: printerConnected ? Cura.MachineManager.printerOutputDevices[0] : null

    Cura.ExtrudersModel
    {
        id: extrudersModel
        simpleNames: true
    }

    Item
    {
        width: base.width - 2 * UM.Theme.getSize("default_margin").width
        height: childrenRect.height + UM.Theme.getSize("default_margin").height
        anchors.left: parent.left
        anchors.leftMargin: UM.Theme.getSize("default_margin").width

        Label
        {
            text: printerConnected ? connectedPrinter.connectionText : catalog.i18nc("@info:status", "The printer is not connected.")
            color: printerConnected && printerAcceptsCommands ? UM.Theme.getColor("setting_control_text") : UM.Theme.getColor("setting_control_disabled_text")
            font: UM.Theme.getFont("default")
            wrapMode: Text.WordWrap
            width: parent.width
        }


    }

    Loader
    {
        sourceComponent: monitorSection
        property string label: catalog.i18nc("@label", "Temperatures")
    }
    Repeater
    {
        model: machineExtruderCount.properties.value
        delegate: Loader
        {
            sourceComponent: monitorItem
            property string label: machineExtruderCount.properties.value > 1 ? extrudersModel.getItem(index).name : catalog.i18nc("@label", "Hotend")
            property string value: printerConnected ? Math.round(connectedPrinter.hotendTemperatures[index]) + "°C" : ""
        }
    }
    Repeater
    {
        model: machineHeatedBed.properties.value == "True" ? 1 : 0
        delegate: Loader
        {
            sourceComponent: monitorItem
            property string label: catalog.i18nc("@label", "Build plate")
            property string value: printerConnected ? Math.round(connectedPrinter.bedTemperature) + "°C" : ""
        }
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
        property string value: printerConnected ? connectedPrinter.jobName : ""
    }
    Loader
    {
        sourceComponent: monitorItem
        property string label: catalog.i18nc("@label", "Printing Time")
        property string value: printerConnected ? getPrettyTime(connectedPrinter.timeTotal) : ""
    }
    Loader
    {
        sourceComponent: monitorItem
        property string label: catalog.i18nc("@label", "Estimated time left")
        property string value: printerConnected ? getPrettyTime(connectedPrinter.timeTotal - connectedPrinter.timeElapsed) : ""
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
                color: printerConnected && printerAcceptsCommands ? UM.Theme.getColor("setting_control_text") : UM.Theme.getColor("setting_control_disabled_text")
                font: UM.Theme.getFont("default")
                elide: Text.ElideRight
            }
            Label
            {
                width: parent.width * 0.6
                anchors.verticalCenter: parent.verticalCenter
                text: value
                color: printerConnected && printerAcceptsCommands ? UM.Theme.getColor("setting_control_text") : UM.Theme.getColor("setting_control_disabled_text")
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
            width: base.width - 2 * UM.Theme.getSize("default_margin").width
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

        Rectangle
        {
            color: UM.Theme.getColor("setting_category")
            width: base.width - 2 * UM.Theme.getSize("default_margin").width
            height: childrenRect.height

            visible: connectedPrinter

            Row
            {
                id: baseControls

                anchors.left: parent.left
                anchors.leftMargin: UM.Theme.getSize("default_margin").width

                Button
                {
                    text: "Connect"
                    onClicked:
                    {
                        connectedPrinter.connect()
                    }
                }

                Button
                {
                    text: "Disconnect"
                    onClicked:
                    {
                        connectedPrinter.close()
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
                }
            }

            GridLayout
            {
                id: controlsLayout
                columns: 4
                rows: 4
                rowSpacing: 1
                columnSpacing: 1

                anchors.top: baseControls.bottom
                anchors.topMargin: UM.Theme.getSize("default_margin").width

                anchors.left: parent.left
                anchors.leftMargin: UM.Theme.getSize("default_margin").width

                Button
                {
                    text: "/\\"
                    Layout.row: 1
                    Layout.column: 2
                    Layout.preferredWidth: UM.Theme.getSize("section").height
                    Layout.preferredHeight: UM.Theme.getSize("section").height

                    onClicked:
                    {
                        connectedPrinter.moveHead(0, -parseFloat(moveLengthTextField.text), 0)
                    }
                }

                Button
                {
                    text: "<"
                    Layout.row: 2
                    Layout.column: 1
                    Layout.preferredWidth: UM.Theme.getSize("section").height
                    Layout.preferredHeight: UM.Theme.getSize("section").height

                    onClicked:
                    {
                        connectedPrinter.moveHead(-parseFloat(moveLengthTextField.text), 0, 0)
                    }
                }

                Button
                {
                    text: ">"
                    Layout.row: 2
                    Layout.column: 3
                    Layout.preferredWidth: UM.Theme.getSize("section").height
                    Layout.preferredHeight: UM.Theme.getSize("section").height

                    onClicked:
                    {
                        connectedPrinter.moveHead(parseFloat(moveLengthTextField.text), 0, 0)
                    }
                }

                Button
                {
                    text: "V"
                    Layout.row: 3
                    Layout.column: 2
                    Layout.preferredWidth: UM.Theme.getSize("section").height
                    Layout.preferredHeight: UM.Theme.getSize("section").height

                    onClicked:
                    {
                        connectedPrinter.moveHead(0, parseFloat(moveLengthTextField.text), 0)
                    }
                }

                Button
                {
                    text: "/\\"
                    Layout.row: 1
                    Layout.column: 4
                    Layout.preferredWidth: UM.Theme.getSize("section").height
                    Layout.preferredHeight: UM.Theme.getSize("section").height

                    onClicked:
                    {
                        connectedPrinter.moveHead(0, 0, parseFloat(moveLengthTextField.text))
                    }
                }

                Button
                {
                    text: "V"
                    Layout.row: 3
                    Layout.column: 4
                    Layout.preferredWidth: UM.Theme.getSize("section").height
                    Layout.preferredHeight: UM.Theme.getSize("section").height

                    onClicked:
                    {
                        connectedPrinter.moveHead(0, 0, -parseFloat(moveLengthTextField.text))
                    }
                }

                Button
                {
                    text: "X"
                    Layout.row: 1
                    Layout.column: 1
                    Layout.preferredWidth: UM.Theme.getSize("section").height
                    Layout.preferredHeight: UM.Theme.getSize("section").height

                    onClicked:
                    {
                        Cura.USBPrinterManager.sendCommandToCurrentPrinter("G28 X")
                    }
                }

                Button
                {
                    text: "Y"
                    Layout.row: 3
                    Layout.column: 1
                    Layout.preferredWidth: UM.Theme.getSize("section").height
                    Layout.preferredHeight: UM.Theme.getSize("section").height

                    onClicked:
                    {
                        Cura.USBPrinterManager.sendCommandToCurrentPrinter("G28 Y")
                    }
                }

                Button
                {
                    text: "H"
                    Layout.row: 2
                    Layout.column: 2
                    Layout.preferredWidth: UM.Theme.getSize("section").height
                    Layout.preferredHeight: UM.Theme.getSize("section").height

                    onClicked:
                    {
                        Cura.USBPrinterManager.sendCommandToCurrentPrinter("G28")
                    }
                }

                Button
                {
                    text: "Z"
                    Layout.row: 2
                    Layout.column: 4
                    Layout.preferredWidth: UM.Theme.getSize("section").height
                    Layout.preferredHeight: UM.Theme.getSize("section").height

                    onClicked:
                    {
                        Cura.USBPrinterManager.sendCommandToCurrentPrinter("G28 Z")
                    }
                }
            }

            GridLayout
            {
                anchors.left: controlsLayout.right
                anchors.leftMargin: 16

                anchors.top: controlsLayout.top

                columns: 2
                rows: 3
                rowSpacing: 1
                columnSpacing: 1

                width: parent.width - controlsLayout.width - 16

                Label
                {
                    text: "Move length"
                    Layout.preferredHeight: UM.Theme.getSize("section").height
                    color: UM.Theme.getColor("setting_control_text")
                    font: UM.Theme.getFont("default")
                }

                TextField
                {
                    text: "1"
                    id: moveLengthTextField
                    Layout.preferredHeight: UM.Theme.getSize("section").height
                    validator: DoubleValidator
                    {
                        bottom: 0
                        top: 100
                    }
                }

                Label
                {
                    text: "Extrusion amount"
                    Layout.preferredHeight: UM.Theme.getSize("section").height
                    color: UM.Theme.getColor("setting_control_text")
                    font: UM.Theme.getFont("default")
                }

                TextField
                {
                    text: "1"
                    id: extrusionAmountTextField
                    Layout.preferredHeight: UM.Theme.getSize("section").height
                    validator: DoubleValidator
                    {
                        bottom: 0
                        top: 10
                    }
                }

                Row
                {
                    Layout.columnSpan: 2
                    Button
                    {
                        text: "Extrude"
                        Layout.preferredHeight: UM.Theme.getSize("section").height
                    }

                    Button
                    {
                        text: "Retract"
                        Layout.preferredHeight: UM.Theme.getSize("section").height
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
}