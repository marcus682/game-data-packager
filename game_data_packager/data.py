#!/usr/bin/python3
# encoding=utf-8
#
# Copyright © 2014-2016 Simon McVittie <smcv@debian.org>
# Copyright © 2015-2016 Alexandre Detiste <alexandre@detiste.be>
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

import hashlib
import io

from .version import (GAME_PACKAGE_VERSION)

class ProgressCallback:
    """API for a progress report."""

    def __call__(self, done, total=None, checkpoint=False):
        """Update progress: we have done @done bytes out of @total
        (None if unknown).

        If @checkpoint is True, it is a hint that this particular
        update is important (for instance the end of a file).
        """
        pass

    def __enter__(self):
        return self

    def __exit__(self, et=None, ev=None, tb=None):
        pass

class HashedFile:
    def __init__(self, name):
        self.name = name
        self._md5 = None
        self._sha1 = None
        self._sha256 = None
        self.skip_hash_matching = False

    @classmethod
    def from_file(cls, name, f, write_to=None, size=None, progress=None):
        return cls.from_concatenated_files(name, [f], write_to, size, progress)

    @classmethod
    def from_concatenated_files(cls, name, fs, write_to=None, size=None,
            progress=None):
        md5 = hashlib.new('md5')
        sha1 = hashlib.new('sha1')
        sha256 = hashlib.new('sha256')
        done = 0

        if progress is None:
            progress = ProgressCallback()

        with progress:
            for f in fs:
                while True:
                    progress(done, size)

                    blob = f.read(io.DEFAULT_BUFFER_SIZE)

                    if not blob:
                        progress(done, size, checkpoint=True)
                        break

                    done += len(blob)

                    md5.update(blob)
                    sha1.update(blob)
                    sha256.update(blob)
                    if write_to is not None:
                        write_to.write(blob)

        self = cls(name)
        self.md5 = md5.hexdigest()
        self.sha1 = sha1.hexdigest()
        self.sha256 = sha256.hexdigest()
        return self

    @property
    def have_hashes(self):
        return ((self.md5 is not None) or
                (self.sha1 is not None) or
                (self.sha256 is not None))

    def matches(self, other):
        matched = False

        if self.skip_hash_matching or other.skip_hash_matching:
            return False

        if None not in (self.md5, other.md5):
            matched = True
            if self.md5 != other.md5:
                return False

        if None not in (self.sha1, other.sha1):
            matched = True
            if self.sha1 != other.sha1:
                return False

        if None not in (self.sha256, other.sha256):
            matched = True
            if self.sha256 != other.sha256:
                return False

        if not matched:
            raise ValueError(('Unable to determine whether checksums match:\n' +
                        '%s has:\n' +
                        '  md5:    %s\n' +
                        '  sha1:   %s\n' +
                        '  sha256: %s\n' +
                        '%s has:\n' +
                        '  md5:    %s\n' +
                        '  sha1:   %s\n' +
                        '  sha256: %s\n') % (
                        self.name,
                        self.md5,
                        self.sha1,
                        self.sha256,
                        other.name,
                        other.md5,
                        other.sha1,
                        other.sha256))

        return True

    @property
    def md5(self):
        return self._md5
    @md5.setter
    def md5(self, value):
        if self._md5 is not None and value != self._md5:
            raise AssertionError('trying to set md5 of "%s" to both %s '
                    + 'and %s', self.name, self._md5, value)
        self._md5 = value

    @property
    def sha1(self):
        return self._sha1
    @sha1.setter
    def sha1(self, value):
        if self._sha1 is not None and value != self._sha1:
            raise AssertionError('trying to set sha1 of "%s" to both %s '
                    + 'and %s', self.name, self._sha1, value)
        self._sha1 = value

    @property
    def sha256(self):
        return self._sha256
    @sha256.setter
    def sha256(self, value):
        if self._sha256 is not None and value != self._sha256:
            raise AssertionError('trying to set sha256 of "%s" to both %s '
                    + 'and %s', self.name, self._sha256, value)
        self._sha256 = value

class WantedFile(HashedFile):
    def __init__(self, name):
        super(WantedFile, self).__init__(name)
        self.alternatives = []
        self.doc = False
        self._distinctive_name = None
        self.distinctive_size = False
        self.download = None
        self.executable = False
        self.filename = name.split('?')[0]
        self.install_as = self.filename
        self._install_to = None
        self.license = False
        self._look_for = None
        self._provides = set()
        self.provides_files = None
        self._size = None
        self.unpack = None
        self.unsuitable = None

    def apply_group_attributes(self, attributes):
        for k, v in attributes.items():
            assert hasattr(self, k)
            setattr(self, k, v)

    @property
    def distinctive_name(self):
        if self._distinctive_name is not None:
            return self._distinctive_name
        return not self.license
    @distinctive_name.setter
    def distinctive_name(self, value):
        self._distinctive_name = value

    @property
    def install_to(self):
        if self._install_to is not None:
            return self._install_to
        if self.doc:
            return '$pkgdocdir'
        if self.license:
            return '$pkglicensedir'
        return None
    @install_to.setter
    def install_to(self, value):
        self._install_to = value

    @property
    def look_for(self):
        if self.alternatives:
            return set([])
        if self._look_for is not None:
            return self._look_for
        return set([self.filename.lower(), self.install_as.lower()])
    @look_for.setter
    def look_for(self, value):
        if isinstance(value, str):
            value = (value,)
        self._look_for = set(x.lower() for x in value)

    @property
    def size(self):
        return self._size
    @size.setter
    def size(self, value):
        if self._size is not None and value != self._size:
            raise AssertionError('trying to set size of "%s" to both %d '
                    + 'and %d', self.name, self._size, value)
        self._size = int(value)

    @property
    def provides(self):
        return self._provides
    @provides.setter
    def provides(self, value):
        self._provides = set(value)

    def to_data(self, expand=True):
        ret = {
            'name': self.name,
        }

        for k in (
                'alternatives',
                'distinctive_size',
                'executable',
                'license',
                'skip_hash_matching',
                ):
            v = getattr(self, k)
            if v:
                if isinstance(v, set):
                    ret[k] = sorted(v)
                else:
                    ret[k] = v

        if expand:
            if self.provides_files:
                ret['provides'] = sorted(f.name for f in self.provides_files)
        else:
            if self.provides:
                ret['provides'] = sorted(self.provides)

        for k in (
                'download',
                'install_as',
                'size',
                'unsuitable',
                'unpack',
                ):
            v = getattr(self, k)
            if v is not None:
                if isinstance(v, set):
                    ret[k] = sorted(v)
                else:
                    ret[k] = v

        for k in (
                'distinctive_name',
                'install_to',
                'look_for',
                ):
            if expand:
                # use derived value
                v = getattr(self, k)
            else:
                v = getattr(self, '_' + k)

            if v is not None:
                if isinstance(v, set):
                    ret[k] = sorted(v)
                else:
                    ret[k] = v

        return ret

class PackageRelation:
    def __init__(self, rel):
        assert isinstance(rel, str) or isinstance(rel, dict)
        assert ',' not in rel

        self.package = None
        self.version = None
        self.version_operator = None
        self.alternatives = []
        self.contextual = {}

        if isinstance(rel, dict):
            for context, specific in rel.items():
                assert isinstance(context, str), context
                assert isinstance(specific, str), specific
                self.contextual[context] = PackageRelation(specific)
        elif '|' in rel:
            self.alternatives = [PackageRelation(bit.strip())
                    for bit in rel.split('|')]
        else:
            for operator in '>=', '>>', '<=', '<<', '=':
                if operator in rel:
                    package, version = rel.split(operator)
                    package = package.rstrip('(')
                    self.package = package.strip()
                    version = version.rstrip(')')
                    self.version = version.strip()
                    self.version_operator = operator
                    break
            else:
                self.package = rel

                assert self.package.strip() == self.package, repr(self.package)

    def to_data(self):
        if self.contextual:
            data = {}

            for context, specific in self.contextual.items():
                data[context] = specific.to_data()

            return data

        if self.alternatives:
            return ' | '.join([alt.to_data() for alt in self.alternatives])

        return str(self)

    def __str__(self):
        if self.contextual:
            ret = []
            for context, specific in self.contextual.items():
                ret.append(repr(context) + ': ' + repr(str(specific)))
            ret.sort()
            return '{' + ', '.join(ret) + '}'

        if self.alternatives:
            return ' | '.join([str(s) for s in self.alternatives])

        if self.version is None:
            return self.package

        return '%s (%s %s)' % (self.package, self.version_operator,
                self.version)

    def __repr__(self):
        return 'PackageRelation(' + repr(self.to_data()) + ')'

class FileGroup:
    __APPLY_TO_ALL = ('doc', 'executable', 'install_to', 'license')

    def __init__(self, name):
        self.name = name
        self.group_members = set()

        # Attributes to apply to every member of this group.
        for attr in self.__APPLY_TO_ALL:
            setattr(self, attr, None)

    def apply_group_attributes(self, other):
        assert isinstance(other, WantedFile) or isinstance(other, FileGroup)

        for attr in self.__APPLY_TO_ALL:
            assert hasattr(other, attr)
            value = getattr(self, attr)

            if value is not None:
                setattr(other, attr, value)

    def to_data(self, expand=True):
        ret = {}

        for attr in self.__APPLY_TO_ALL:
            value = getattr(self, attr)

            if value is not None:
                ret[attr] = value

        return ret

class Package(object):
    def __init__(self, name, data):
        # The name of the binary package
        self.name = name

        # Other names for this binary package
        self._aliases = set()

        # Names of relative packages
        self.demo_for = set()
        self._better_versions = set()
        self.expansion_for = None
        # use this for games with demo_for/better_version/provides
        self.mutually_exclusive = False
        # expansion for a package outside of this yaml file;
        # may be another GDP package or a package not made by GDP
        self.expansion_for_ext = None

        self.relations = dict(
            breaks=[],
            build_depends=[],
            conflicts=[],
            depends=[],
            provides=[],
            recommends=[],
            replaces=[],
            suggests=[],
        )

        # The optional marketing name of this version
        self.longname = None

        # This word is used to build package description
        # 'data' / 'music' / 'documentation' / 'PWAD' / 'IWAD' / 'binaries'
        self.data_type = 'data'

        # if not None, override the description completely
        self.long_description = None

        # extra blurb of text added to .deb long description
        self.description = None

        # first line of .deb description, or None to construct one from
        # longname
        self.short_description = None

        # This optional value will overide the game global copyright
        self.copyright = None

        # A blurb of text that is used to build debian/copyright
        self.copyright_notice = None

        # Languages, list of ISO-639 codes
        self.langs = ['en']

        # Where we install files.
        # For instance, if this is 'usr/share/games/quake3' and we have
        # a WantedFile with install_as='baseq3/pak1.pk3' then we would
        # put 'usr/share/games/quake3/baseq3/pak1.pk3' in the .deb.
        # The default is 'usr/share/games/' plus the binary package's name.
        if name.endswith('-data'):
            self.default_install_to = '$assets/' + name[:len(name) - 5]
        else:
            self.default_install_to = '$assets/' + name

        self.install_to = self.default_install_to

        # If true, this package is allowed to be empty
        self.empty = False

        # symlink => real file (the opposite way round that debhelper does it,
        # because the links must be unique but the real files are not
        # necessarily)
        self.symlinks = {}

        # online stores metadata
        self.steam = {}
        self.gog = {}
        self.dotemu = {}
        self.origin = {}
        self.url_misc = None

        # overide the game engine when needed
        self.engine = None

        # expansion's dedicated Wiki page, appended to GameData.wikibase
        self.wiki = None

        # format- and distribution-specific overrides
        self.specifics = {}

        # set of names of WantedFile instances to be installed
        self._install = set()

        # set of names of WantedFile instances to be optionally installed
        self._optional = set()

        # set of WantedFile instances for install, with groups expanded
        # only available after load_file_data()
        self.install_files = None
        # set of WantedFile instances for optional, with groups expanded
        self.optional_files = None

        self.version = GAME_PACKAGE_VERSION

        # CD audio stuff from YAML
        self.rip_cd = {}

        # possible override for disks: tag at top level
        # e.g.: Feeble Files had 2-CD releases too
        self.disks = None

        # Debian architecture(s)
        self.architecture = 'all'

        # Component (archive area): main, contrib, non-free, local
        # We use "local" to mean "not distributable"; the others correspond
        # to components in the Debian archive
        self.component = 'local'
        self.section = 'games'

        # show output of external tools?
        self.verbose = False

        # archives actually used to built a package
        self.used_sources = set()

        for k in (
                'aliases',
                'architecture',
                'better_versions',
                'component',
                'copyright',
                'copyright_notice',
                'description',
                'disks',
                'dotemu',
                'empty',
                'engine',
                'expansion_for',
                'expansion_for_ext',
                'gog',
                'install_to',
                'lang',
                'langs',
                'long_description',
                'longname',
                'mutually_exclusive',
                'origin',
                'rip_cd',
                'section',
                'short_description',
                'steam',
                'symlinks',
                'url_misc',
                'wiki',
                ):
            if k in data:
                setattr(self, k, data[k])

        if 'better_version' in data:
            assert 'better_versions' not in data
            self.better_versions = set([data['better_version']])

        for rel in self.relations:
            if rel in data:
                related = data[rel]

                if isinstance(related, (str, dict)):
                    related = [related]
                else:
                    assert isinstance(related, list)

                for x in related:
                    pr = PackageRelation(x)
                    # Fedora doesn't handle alternatives, everything must
                    # be handled with virtual packages. Assume the same is
                    # true for everything except dpkg.
                    assert not pr.alternatives, pr

                    if pr.contextual:
                        for context, specific in pr.contextual.items():
                            assert (context == 'deb' or
                                    not specific.alternatives), pr

                    if pr.package == 'libjpeg.so.62':
                        # we can't really translate versions for libjpeg,
                        # since it could be either libjpeg6b or libjpeg-turbo
                        assert pr.version is None

                    self.relations[rel].append(pr)

        for port in ('debian', 'rpm', 'arch', 'fedora', 'mageia', 'suse'):
            assert port not in data, 'use {deb: foo-dfsg, generic: foo} syntax'

        assert self.component in ('main', 'contrib', 'non-free', 'local')
        assert self.component == 'local' or 'license' in data
        assert self.section in ('games', 'doc'), 'unsupported'
        assert type(self.langs) is list
        assert type(self.mutually_exclusive) is bool

        for rel, related in self.relations.items():
            for pr in related:
                packages = set()
                if pr.contextual:
                    for p in pr.contextual.values():
                        packages.add(p.package)
                elif pr.alternatives:
                    for p in pr.alternatives:
                        packages.add(p.package)
                else:
                    packages.add(pr.package)
                assert self.name not in packages, \
                   "%s should not be in its own %s set" % (self.name, rel)

        if isinstance(self.install_to, dict):
            self.install_to.setdefault('generic',
                    self.default_install_to)

        if 'install_to' in data and isinstance(data['install_to'], str):
            assert data['install_to'] != self.default_install_to, \
                "install_to for %s is extraneous" % self.name

        if 'demo_for' in data:
            if self.disks is None:
                self.disks = 1
            if type(data['demo_for']) is str:
                self.demo_for.add(data['demo_for'])
            else:
                self.demo_for |= set(data['demo_for'])
            assert self.name != data['demo_for'], "a game can't be a demo for itself"

        if self.mutually_exclusive:
            assert self.demo_for or self.better_versions or self.relations['provides']

        if 'expansion_for' in data:
            if self.disks is None:
                self.disks = 1
            assert self.name != data['expansion_for'], \
                   "a game can't be an expansion for itself"
            if 'demo_for' in data:
                raise AssertionError("%r can't be both a demo of %r and an " +
                        "expansion for %r" % (self.name, data.demo_for,
                            data.expansion_for))

        if 'install' in data:
            for filename in data['install']:
                self.install.add(filename)

        if 'optional' in data:
            assert isinstance(data['optional'], list), self.name
            for filename in data['optional']:
                self.optional.add(filename)

        if 'doc' in data:
            assert isinstance(data['doc'], list), self.name
            for filename in data['doc']:
                self.optional.add(filename)

        if 'license' in data:
            assert isinstance(data['license'], list), self.name
            for filename in data['license']:
                self.optional.add(filename)

        if 'version' in data:
            self.version = data['version'] + '+' + GAME_PACKAGE_VERSION

        if 'rip_cd' in data:
            self.data_type = 'music'
        elif self.section == 'doc':
            self.data_type = 'documentation'

    @property
    def aliases(self):
        return self._aliases
    @aliases.setter
    def aliases(self, value):
        self._aliases = set(value)

    @property
    def install(self):
        return self._install
    @install.setter
    def install(self, value):
        self._install = set(value)

    @property
    def only_file(self):
        if len(self._install) == 1:
            return list(self._install)[0]
        else:
            return None

    @property
    def optional(self):
        return self._optional
    @optional.setter
    def optional(self, value):
        self._optional = set(value)

    @property
    def better_versions(self):
        return self._better_versions
    @better_versions.setter
    def better_versions(self, value):
        self._better_versions = set(value)

    @property
    def type(self):
        """type of package: full, demo or expansion

        full packages include quake-registered, quake2-full-data, quake3-data
        demo packages include quake-shareware, quake2-demo-data
        expansion packages include quake-armagon, quake-music, quake2-rogue
        """
        if self.demo_for:
            return 'demo'
        if self.expansion_for or self.expansion_for_ext:
            return 'expansion'
        return 'full'

    @property
    def lang(self):
        return self.langs[0]

    @lang.setter
    def lang(self, value):
        assert type(value) is str
        self.langs = [value]

    def to_data(self, expand=True):
        ret = {
            'architecture': self.architecture,
            'component': self.component,
            'install_to': self.install_to,
            'name': self.name,
            'section': self.section,
            'type': self.type,
            'version': self.version,
        }

        for k in (
                'aliases',
                'better_versions',
                'demo_for',
                'dotemu',
                'gog',
                'origin',
                'rip_cd',
                'specifics',
                'steam',
                'symlinks',
                ):
            v = getattr(self, k)
            if v:
                if isinstance(v, set):
                    ret[k] = sorted(v)
                else:
                    ret[k] = v

        for relation, related in self.relations.items():
            # The .to_data() of a PackageRelation doesn't have a defined
            # sorting order, so do a Schwartzian transform to get a
            # stable order
            tmp = sorted([(str(x), x.to_data()) for x in related])
            tmp = [x[1] for x in tmp]
            ret[relation] = tmp

        if expand and self.install_files is not None:
            if self.install_files:
                ret['install'] = sorted(f.name for f in self.install_files)
            if self.optional_files:
                ret['optional'] = sorted(f.name for f in self.optional_files)
        else:
            if self.install:
                ret['install'] = sorted(self.install)
            if self.optional:
                ret['optional'] = sorted(self.optional)

        for k in (
                'copyright',
                'copyright_notice',
                'description',
                'disks',
                'engine',
                'expansion_for',
                'expansion_for_ext',
                'longname',
                'long_description',
                'short_description',
                'url_misc',
                'wiki',
                ):
            v = getattr(self, k)
            if v is not None:
                ret[k] = v

        return ret
