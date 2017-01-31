import QtQuick 2.2
import QtQuick.Controls 1.1
import QtQuick.Controls.Styles 1.1
import QtQuick.Layouts 1.1

import UM 1.2 as UM
import Cura 1.0 as Cura

Item
{
    property var connectedPrinter: printerConnected ? Cura.MachineManager.printerOutputDevices[0] : null
    height: childrenRect.height + UM.Theme.getSize("default_margin").width * 2

    Column
    {
        width: 100
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: UM.Theme.getSize("default_margin").width

        Button
        {
            text: "Wipe nozzle"
            width: parent.width

            onClicked:
            {
                connectedPrinter.wipeNozzle()
            }
        }

        Button
        {
            text: "Preheat nozzle"
            width: parent.width

            onClicked:
            {
                connectedPrinter.preheatHotend(extruderSelector.currentIndex)
            }
        }

        Button
        {
            text: "Preheat bed"
            width: parent.width

            onClicked:
            {
                connectedPrinter.preheatBed()
            }
        }

        Button
        {
            text: "Motors off"
            width: parent.width

            onClicked:
            {
                Cura.USBPrinterManager.sendCommandToCurrentPrinter("M18")
            }
        }

        Button
        {
            text: "Cool nozzle"
            width: parent.width

            onClicked:
            {
                connectedPrinter.setTargetHotendTemperature(extruderSelector.currentIndex, 0)
            }
        }

        Button
        {
            text: "Cool bed"
            width: parent.width

            onClicked:
            {
                connectedPrinter.setTargetBedTemperature(0)
            }
        }

        Button
        {
            text: "Cold pull"
            width: parent.width

            onClicked:
            {
                connectedPrinter.coldPull(extruderSelector.currentIndex)
            }
        }
    }
}