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
                base.command(command_field.text);
            }
        }
    ]

    onAccepted:
    {
        base.command(command_field.text);
        base.visible = true
    }
}

