from UM.Settings.Models.InstanceContainersModel import InstanceContainersModel
from UM.Application import Application
from UM.Settings.ContainerRegistry import ContainerRegistry

##  A model that shows a list of currently valid materials.
class MaterialsModel(InstanceContainersModel):
    def __init__(self, parent = None):
        super().__init__(parent)

        ContainerRegistry.getInstance().containerMetaDataChanged.connect(self._onContainerMetaDataChanged)

    ##  Called when the metadata of the container was changed.
    #
    #   This makes sure that we only update when it was a material that changed.
    #
    #   \param container The container whose metadata was changed.
    def _onContainerMetaDataChanged(self, container):
        if container.getMetaDataEntry("type") == "material": #Only need to update if a material was changed.
            self._update()

    def _fetchInstanceContainers(self):
        results = super()._fetchInstanceContainers()
        if Application.getInstance().getMachineManager().currentCategory != "Experimental":
            for material in results:
                if material.getMetaDataEntry("category", None) == "Experimental":
                    results.remove(material)
        return results
