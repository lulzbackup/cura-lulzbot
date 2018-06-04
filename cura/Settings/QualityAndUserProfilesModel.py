# Copyright (c) 2016 Ultimaker B.V.
# Cura is released under the terms of the LGPLv3 or higher.
from UM.Application import Application
from UM.Settings.ContainerRegistry import ContainerRegistry

from cura.QualityManager import QualityManager
from cura.Settings.ProfilesModel import ProfilesModel
from cura.Settings.ExtruderManager import ExtruderManager


##  QML Model for listing the current list of valid quality and quality changes profiles.
#
class QualityAndUserProfilesModel(ProfilesModel):
    def __init__(self, parent = None):
        super().__init__(parent)

        self._empty_quality = ContainerRegistry.getInstance().findInstanceContainers(id = "empty_quality")[0]

    ##  Fetch the list of containers to display.
    #
    #   See UM.Settings.Models.InstanceContainersModel._fetchInstanceContainers().
    def _fetchInstanceContainers(self):
        global_container_stack = Application.getInstance().getGlobalContainerStack()
        if not global_container_stack:
            return {}, {}

        # Fetch the list of quality changes.
        quality_manager = QualityManager.getInstance()
        machine_definition = quality_manager.getParentMachineDefinition(global_container_stack.definition)
        quality_changes_list = quality_manager.findAllQualityChangesForMachine(machine_definition)

        extruder_manager = ExtruderManager.getInstance()
        active_extruder = extruder_manager.getActiveExtruderStack()
        extruder_stacks = self._getOrderedExtruderStacksList()

        # Fetch the list of usable qualities across all extruders.
        # The actual list of quality profiles come from the first extruder in the extruder list.
        quality_list = quality_manager.findAllUsableQualitiesForMachineAndExtruders(global_container_stack, extruder_stacks)

        # Filter the quality_change by the list of available quality_types
        quality_type_set = set([x.getMetaDataEntry("quality_type") for x in quality_list])
        # Also show custom profiles based on "Not Supported" quality profile
        quality_type_set.add(self._empty_quality.getMetaDataEntry("quality_type"))
        filtered_quality_changes = {qc.getId(): qc for qc in quality_changes_list if
                                    qc.getMetaDataEntry("quality_type") in quality_type_set and
                                    ((qc.getMetaDataEntry("extruder") == active_extruder.definition.getMetaDataEntry("quality_definition") or
                                     qc.getMetaDataEntry("extruder") == active_extruder.definition.getId()) if qc.getMetaDataEntry("extruder") is not None else True) and
                                    ((qc.getMetaDataEntry("material") == active_extruder.material.id) if machine_definition.getMetaDataEntry("has_machine_materials") else True)}

        result = filtered_quality_changes
        for q in quality_list:
            if q.getId() != "empty_quality":
                result[q.getId()] = q
        return result, {} #Only return true profiles for now, no metadata. The quality manager is not able to get only metadata yet.
