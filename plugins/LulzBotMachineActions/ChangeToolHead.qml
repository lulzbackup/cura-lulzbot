import QtQuick 2.2
import QtQuick.Controls 1.1
import QtQuick.Layouts 1.1
import QtQuick.Window 2.1
import QtQuick.Dialogs 1.2 // For filedialog

import UM 1.2 as UM
import Cura 1.0 as Cura


Cura.MachineAction
{
    anchors.fill: parent;
    Item
    {
        id: changeToolHeadMachineAction
        anchors.fill: parent;
        UM.I18nCatalog { id: catalog; name:"cura"}

        Label
        {
            id: pageTitle
            width: parent.width
            text: catalog.i18nc("@title", "Change Tool Head")
            wrapMode: Text.WordWrap
            font.pointSize: 18
        }
        Label
        {
            id: pageDescription
            anchors.top: pageTitle.bottom
            anchors.topMargin: UM.Theme.getSize("default_margin").height
            width: parent.width
            wrapMode: Text.WordWrap
            text: catalog.i18nc("@label", "Tool head was changed, you need to change machine firmware")
        }

        Label
        {
            id: upgradeText1
            anchors.top: pageDescription.bottom
            anchors.topMargin: UM.Theme.getSize("default_margin").height
            width: parent.width
            wrapMode: Text.WordWrap
            text: catalog.i18nc("@label", "Incorrect firmware can damage your printer");
        }

        Row
        {
            id: buttonRow
            anchors.top: upgradeText1.bottom
            anchors.topMargin: UM.Theme.getSize("default_margin").height
            anchors.horizontalCenter: parent.horizontalCenter
            width: childrenRect.width
            spacing: UM.Theme.getSize("default_margin").width
            property var firmwareName: Cura.USBPrinterManager.getDefaultFirmwareName()
            Button
            {
                id: autoUpgradeButton
                text: catalog.i18nc("@action:button", "Automatically change Firmware");
                enabled: parent.firmwareName != ""
                onClicked:
                {
                    Cura.USBPrinterManager.updateAllFirmware(parent.firmwareName, updateEepromCheckbox.checked)
                }
            }
            Button
            {
                id: manualUpgradeButton
                text: catalog.i18nc("@action:button", "Upload custom Firmware");
                onClicked:
                {
                    customFirmwareDialog.open()
                }
            }
        }
        Row
        {
            anchors.topMargin: UM.Theme.getSize("default_margin").height
            anchors.top: buttonRow.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            CheckBox
            {
                id: updateEepromCheckbox
                text: qsTr("Update EEPROM")
                checked: true

            }
        }

        FileDialog
        {
            id: customFirmwareDialog
            title: catalog.i18nc("@title:window", "Select custom firmware")
            nameFilters:  "Firmware image files (*.hex)"
            selectExisting: true
            onAccepted: Cura.USBPrinterManager.updateAllFirmware(fileUrl, updateEepromCheckbox.checked)
        }
    }
}