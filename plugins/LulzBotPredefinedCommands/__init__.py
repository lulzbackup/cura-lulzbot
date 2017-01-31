# Copyright (c) 2016 Aleph Objects, Inc.
# Cura is released under the terms of the AGPLv3 or higher.

from UM.i18n import i18nCatalog
from . import LulzBotPredefinedCommands
i18n_catalog = i18nCatalog("cura")

def getMetaData():
    return {
        "plugin": {
            "name": i18n_catalog.i18nc("@label", "LulzBot predefined commands"),
            "author": "Victor Larchenko",
            "version": "1.0",
            "description": i18n_catalog.i18nc("@info:whatsthis", ""),
            "api": 3
        }
    }

def register(app):
    return {"extension": LulzBotPredefinedCommands.LulzBotPredefinedCommands()}
