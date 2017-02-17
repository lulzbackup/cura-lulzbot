# Copyright (c) 2017 Aleph Objects, Inc.
# Cura is released under the terms of the AGPLv3 or higher.

from UM.Logger import Logger
from cura.ProfileWriter import ProfileWriter

class LegacyProfileWriter(ProfileWriter):
    ##  Writes a profile to the specified file path.
    #
    #   \param path \type{string} The file to output to.
    #   \param profiles \type{Profile} \type{List} The profile(s) to write to that file.
    #   \return \code True \endcode if the writing was successful, or \code
    #   False \endcode if it wasn't.
    def write(self, path, profiles):
        return True
