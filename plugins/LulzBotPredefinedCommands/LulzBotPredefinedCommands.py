from UM.Extension import Extension

from UM.i18n import i18nCatalog
i18n_catalog = i18nCatalog("LulzBotPredefinedCommands")
import os
from UM.Application import Application


class LulzBotPredefinedCommands(Extension):
    def __init__(self):
        super().__init__()
        Application.getInstance().registerPrintMonitorAdditionalCategory("Predefined Commands",os.path.join(os.path.dirname(__file__), "Commands.qml"))