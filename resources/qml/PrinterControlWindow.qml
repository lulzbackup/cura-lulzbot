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

    minimumWidth: 500 * Screen.devicePixelRatio
    minimumHeight: 400 * Screen.devicePixelRatio
    width: minimumWidth
    height: minimumHeight
    signal command(string command)
    signal receive(string command)

    property var history_list: []
    property var current_history_index: -1

    property var locale: Qt.locale()

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
            command_log.text += "> [" + new Date().toLocaleTimeString(locale, "hh:mm:ss") + "] " + cmd + "\n";
        }
        command_field.forceActiveFocus();
    }

    onReceive:
    {
        command_log.text += "< [" + new Date().toLocaleTimeString(locale, "hh:mm:ss") + "] " + command + "\n"
    }

    TextArea
    {
        id: command_log
        anchors
        {
            top: parent.top
            topMargin: UM.Theme.getSize("default_margin").width
            left: parent.left
            leftMargin: UM.Theme.getSize("default_margin").width
            right: parent.right
            rightMargin: UM.Theme.getSize("default_margin").width
            bottom: command_field.top
        }
        readOnly: true
        text: ""
    }


    TextField
    {
        id: command_field;

        anchors
        {
            bottom: parent.bottom
            left: parent.left
            leftMargin: UM.Theme.getSize("default_margin").width
            right: parent.right
            rightMargin: UM.Theme.getSize("default_margin").width
        }

        text: ""
        font.capitalization: Font.AllUppercase

        Keys.onPressed:
        {
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

