// Copyright (c) 2016 Ultimaker B.V.
// Cura is released under the terms of the LGPLv3 or higher.

import QtQuick 2.2
import QtQuick.Controls 1.1

import UM 1.2 as UM
import Cura 1.2 as Cura

Menu
{
    title: catalog.i18nc("@title:menu menubar:toplevel", "&View");
    id: base
    enabled: !PrintInformation.preSliced

    // main views
    Instantiator
    {
        model: UM.ViewModel{}
        MenuItem
        {
            text: model.name
            checkable: true
            checked: model.active
            exclusiveGroup: group
            onTriggered: UM.Controller.setActiveView(model.id)
        }
        onObjectAdded: base.insertItem(index, object)
        onObjectRemoved: base.removeItem(object)
    }
    ExclusiveGroup { id: group }

    MenuSeparator {}

    Menu
    {
        title: catalog.i18nc("@action:inmenu menubar:view","&Camera Position");
        MenuItem { action: Cura.Actions.view3DCamera; }
        MenuItem { action: Cura.Actions.viewFrontCamera; }
        MenuItem { action: Cura.Actions.viewTopCamera; }
        MenuItem { action: Cura.Actions.viewLeftSideCamera; }
        MenuItem { action: Cura.Actions.viewRightSideCamera; }
        MenuItem { action: Cura.Actions.viewBottomSideCamera; }
    }

    MenuSeparator {
        visible: UM.Preferences.getValue("cura/use_multi_build_plate")
    }

    Menu
    {
        id: buildPlateMenu;
        title: catalog.i18nc("@action:inmenu menubar:view","&Build plate");
        visible: UM.Preferences.getValue("cura/use_multi_build_plate")
        Instantiator
        {
            model: Cura.BuildPlateModel
            MenuItem {
                text: Cura.BuildPlateModel.getItem(index).name;
                onTriggered: Cura.SceneController.setActiveBuildPlate(Cura.BuildPlateModel.getItem(index).buildPlateNumber);
                checkable: true;
                checked: Cura.BuildPlateModel.getItem(index).buildPlateNumber == Cura.BuildPlateModel.activeBuildPlate;
                exclusiveGroup: buildPlateGroup;
                visible: UM.Preferences.getValue("cura/use_multi_build_plate")
            }
            onObjectAdded: buildPlateMenu.insertItem(index, object);
            onObjectRemoved: buildPlateMenu.removeItem(object)
        }
        ExclusiveGroup { id: buildPlateGroup; }
    }

    MenuSeparator {}

    MenuItem { action: Cura.Actions.expandSidebar; }
}
