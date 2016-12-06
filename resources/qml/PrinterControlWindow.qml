// Copyright (c) 2015 Ultimaker B.V.
// Cura is released under the terms of the AGPLv3 or higher.

import QtQuick 2.2
import QtQuick.Controls 1.1
import QtQuick.Window 2.1

import UM 1.1 as UM

UM.Dialog
{
    id: base

    title: catalog.i18nc("@title:window","Printer control")

    minimumWidth: 300 * Screen.devicePixelRatio
    minimumHeight: 100 * Screen.devicePixelRatio
    width: minimumWidth
    height: minimumHeight
    signal command(string command)

    property var history_list: []
    property var current_history_index: -1

    function sendCommand()
    {
        var cmd = command_field.text;
        if (cmd.length > 0)
        {
            cmd = cmd.toUpperCase();
            history_list.push(cmd);
            base.command(cmd);
            command_field.text = "";
            current_history_index = -1;
        }
        command_field.forceActiveFocus();
    }


    TextField
    {
        id: command_field;

        anchors
        {
            top: parent.top
            left: parent.left
            leftMargin: UM.Theme.getSize("default_margin").width
            right: parent.right
        }

        text: ""
        font.capitalization: Font.AllUppercase

        Keys.onPressed:
        {
            console.log(event);
            if (event.key == Qt.Key_Up)
            {
                if (current_history_index < history_list.length - 1)
                {
                    current_history_index += 1;
                    text = history_list[history_list.length - current_history_index - 1];
                }
                event.accepted = true;
            }
            else if (event.key == Qt.Key_Down)
            {
                if (current_history_index > 0)
                {
                    current_history_index -= 1;
                    text = history_list[history_list.length - current_history_index - 1];
                }
                else if (current_history_index == 0)
                {
                    text = "";
                    current_history_index = -1;
                }
                event.accepted = true;
            }
            else
            {
                current_history_index = 0;
            }
        }
    }

    rightButtons: [
        Button
        {
            text: catalog.i18nc("@action:button","Close");
            onClicked: base.visible = false;
        },

        Button
        {
            text: catalog.i18nc("@action:button","Send Command");

            onClicked:
            {
                base.sendCommand();
            }
        }
    ]

    onAccepted:
    {
        base.visible = true
        base.sendCommand();
    }
}

