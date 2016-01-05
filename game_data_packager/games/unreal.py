#!/usr/bin/python3
# encoding=utf-8
#
# Copyright © 2016 Simon McVittie <smcv@debian.org>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# You can find the GPL license text on a Debian system under
# /usr/share/common-licenses/GPL-2.

import logging
import os

from .. import (GameData)
from ..build import (PackagingTask)
from ..util import (TemporaryUmask, mkdir_p)
from ..version import (ASSETS)

logger = logging.getLogger('game-data-packager.games.unreal')

class UnrealTask(PackagingTask):
    def fill_extra_files(self, package, destdir):
        super(UnrealTask, self).fill_extra_files(package, destdir)

        if package.name == 'unreal-data':
            with TemporaryUmask(0o022):
                self.__convert_logo(destdir)

    def __convert_logo(self, destdir):
        skaarj_logo = os.path.join(destdir, ASSETS, 'unreal',
                'skaarj_logo.jpg')

        try:
            import gi
            gi.require_version('GdkPixbuf', '2.0')
            from gi.repository import GdkPixbuf
        except:
            logger.warning('Unable to load GdkPixbuf bindings. Unreal icon '
                    'will not be resized or converted')
            return

        mkdir_p(os.path.join(destdir, 'usr', 'share', 'icons',
                'hicolor', '48x48', 'apps'))
        mkdir_p(os.path.join(destdir, 'usr', 'share', 'icons',
                'hicolor', '256x256', 'apps'))

        pixbuf = GdkPixbuf.Pixbuf.new_from_file(skaarj_logo)
        pixbuf.savev(os.path.join(destdir, 'usr', 'share', 'icons',
                    'hicolor', '256x256', 'apps', 'unreal.png'),
                'png', [], [])

        pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_size(skaarj_logo, 48, 48)
        pixbuf.savev(os.path.join(destdir, 'usr', 'share', 'icons',
                    'hicolor', '48x48', 'apps', 'unreal.png'),
                'png', [], [])

class UnrealGameData(GameData):
    def construct_task(self, **kwargs):
        return UnrealTask(self, **kwargs)

GAME_DATA_SUBCLASS = UnrealGameData