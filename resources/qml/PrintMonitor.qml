// Copyright (c) 2016 Ultimaker B.V.
// Cura is released under the terms of the AGPLv3 or higher.

import QtQuick 2.2
import QtQuick.Controls 1.1
import QtQuick.Controls.Styles 1.1
import QtQuick.Layouts 1.1

import UM 1.2 as UM
import Cura 1.0 as Cura

ScrollView
{
    property var connectedPrinter: printerConnected ? Cura.MachineManager.printerOutputDevices[0] : null

    style: UM.Theme.styles.scrollview;
    flickableItem.flickableDirection: Flickable.VerticalFlick;

    Column
    {
        id: printMonitor


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

        function loadSection(label, path)
        {
            var title = Qt.createQmlObject('import QtQuick 2.2; Loader {property string label: ""}', printMonitor);
            title.sourceComponent = monitorSection
            title.label = label
            var content = Qt.createQmlObject('import QtQuick 2.2; Loader {}', printMonitor);
            content.source = path
            content.item.width = base.width - 2 * UM.Theme.getSize("default_margin").width
        }

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

            Item
            {
                width: base.width - 2 * UM.Theme.getSize("default_margin").width
                height: childrenRect.height + 2 * UM.Theme.getSize("default_margin").width

                enabled: connectedPrinter

                Row
                {
                    id: baseControls

                    anchors.left: parent.left
                    anchors.leftMargin: UM.Theme.getSize("default_margin").width
                    anchors.top: parent.top
                    anchors.topMargin: UM.Theme.getSize("default_margin").width

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
                    rows: 3
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
                            connectedPrinter.homeX()
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
                            connectedPrinter.homeY()
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
                            connectedPrinter.homeHead()
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
                            connectedPrinter.homeBed()
                        }
                    }
                }

                Column
                {
                    id: settingColumn

                    anchors.left: controlsLayout.right
                    anchors.leftMargin: UM.Theme.getSize("default_margin").width
                    anchors.top: controlsLayout.top

                    width: parent.width - controlsLayout.width - UM.Theme.getSize("default_margin").width * 3
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

                            model: machineExtruderCount.properties.value

                            onCurrentIndexChanged:
                            {
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

                        Button
                        {
                            text: "Extrude"
                            width: parent.width / 2

                            onClicked:
                            {
                                connectedPrinter.extrude(parseFloat(extrusionAmountTextField.text))
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
                            text: "0"
                            id: temperatureTextField
                            width: parent.width / 2
                            validator: IntValidator
                            {
                                bottom: 0
                                top: 300
                            }
                        }
                    }

                    Row
                    {
                        width: parent.width
                        height: childrenRect.height

                        Button
                        {
                            text: "Heat extruder"
                            width: parent.width / 2

                            onClicked:
                            {
                                connectedPrinter.setTargetHotendTemperature(extruderSelector.currentIndex, parseInt(temperatureTextField.text))
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
                        }
                    }
                }

                Timer
                {
                    interval: 1000
                    running: true
                    repeat: true

                    onTriggered: temperatureGraph.updateValues()
                }

                Canvas
                {
                    anchors.top: settingColumn.bottom
                    anchors.left: settingColumn.left
                    anchors.right: parent.right
                    height: width / 3

                    anchors.topMargin: UM.Theme.getSize("default_margin").width
                    anchors.rightMargin: UM.Theme.getSize("default_margin").width
                    anchors.bottomMargin: UM.Theme.getSize("default_margin").width

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
                        ctx.strokeStyle = Qt.rgba(.3, .3, .3, 1);

                        for(var i = 0; i < 6; i++)
                        {
                            if(i > 0)
                            {
                                ctx.beginPath();
                                ctx.moveTo(0, temperatureGraph.height / 6 * i);
                                ctx.lineTo(temperatureGraph.width, temperatureGraph.height / 6 * i);
                                ctx.closePath();
                                ctx.stroke();
                            }
                        }

                        for(var k = 0; k < nozzleTemperatureValues.length; k++)
                        {
                            ctx.strokeStyle = lineStyles[k];

                            ctx.beginPath();
                            ctx.moveTo(0, temperatureGraph.height + 1);
                            for(var i = 0; i < nozzleTemperatureValues[k].length; i++)
                            {
                                ctx.lineTo(i * temperatureGraph.width / (nozzleTemperatureValues[k].length - 1), temperatureGraph.height - nozzleTemperatureValues[k][i] / 300 * temperatureGraph.height);
                            }
                            ctx.lineTo(temperatureGraph.width, temperatureGraph.height + 1);
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
                        for(var i = 0; i < 6; i++)
                        {
                            ctx.fillText((5-i) * 50, 0, temperatureGraph.height / 6 * (i+1))
                        }

                        ctx.restore();
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
}