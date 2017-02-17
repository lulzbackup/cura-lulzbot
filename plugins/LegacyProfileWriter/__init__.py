# Copyright (c) 2017 Aleph Objects, Inc.
# Cura is released under the terms of the AGPLv3 or higher.


from . import LegacyProfileWriter

from UM.i18n import i18nCatalog
catalog = i18nCatalog("cura")

def getMetaData():
    return {
        "plugin": {
            "name": catalog.i18nc("@label", "Legacy Profile Writer"),
            "author": "Aleph Objects, Inc.",
            "version": "1.0",
            "description": catalog.i18nc("@info:whatsthis", "Provides support for exporting Cura Original profiles."),
            "api": 3
        },
        "profile_writer": [
            {
                "extension": "ini",
                "description": catalog.i18nc("@item:inlistbox", "Cura Profile")
            }
        ]
    }

def register(app):
    return { "profile_writer": LegacyProfileWriter.LegacyProfileWriter() }
