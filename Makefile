-include configure.mk

pkgdatadir := ${gamedatadir}/game-data-packager
runtimedir := ${gamedatadir}/game-data-packager-runtime
PYFLAKES3 := $(shell if [ -x /usr/bin/pyflakes3 ] ;  then echo pyflakes3 ; \
                   elif [ -x /usr/bin/pyflakes3k ] ; then echo pyflakes3k ; \
                   elif [ -x /usr/bin/python3-pyflakes ] ; then echo python3-pyflakes ; \
                   else ls -1 /usr/bin/pyflakes-python3.* | tail -n 1 ; \
                    fi)

png_from_xpm := $(patsubst ./data/%.xpm,./out/%.png,$(wildcard ./data/*.xpm))
png_from_svg := $(patsubst ./data/%.svg,./out/%.png,$(filter-out ./data/quake1+2.svg,$(wildcard ./data/*.svg)))
png       := $(png_from_xpm) $(png_from_svg) out/memento-mori.png
simplified_svg := $(patsubst ./data/%.svg,./out/%.svg,$(filter-out ./data/quake1+2.svg,$(wildcard ./data/*.svg)))
# We deliberately don't compress and install memento-mori{,-2}.svg because
# they use features that aren't supported by librsvg, so they'd look wrong
# in all GTK-based environments.
svgz      := $(patsubst ./out/%.svg,./out/%.svgz,$(filter-out ./out/memento-mori-2.svg,$(simplified_svg)))
in_yaml   := $(wildcard ./data/*.yaml)
json_from_data := $(patsubst ./data/%.yaml,./out/vfs/%.json,$(in_yaml))
copyright := $(patsubst ./data/%,./out/%,$(wildcard ./data/*.copyright) ./data/copyright)
dot_in    := $(patsubst ./data/%,./out/%,$(wildcard ./data/*.in))
desktop   := $(patsubst ./runtime/%.in,./out/%,$(wildcard ./runtime/*.desktop.in))

launcher_json := $(patsubst ./runtime/launch-%.yaml.in,./out/launch-%.json,$(wildcard ./runtime/launch-*.yaml.in))
launcher_desktops := \
	out/unreal.desktop \
	out/unreal-gold.desktop \
	$(NULL)

quake_layer_sizes = 16 22 32 48 256

quake_icons = \
	out/24/quake.png \
	out/24/quake-armagon.png \
	out/24/quake-dissolution.png \
	out/24/quake2.png \
	out/24/quake2-reckoning.png \
	out/24/quake2-groundzero.png \
	out/24/quake4.png \
	out/quake.svg \
	out/quake-armagon.svg \
	out/quake-dissolution.svg \
	out/quake2.svg \
	out/quake2-reckoning.svg \
	out/quake2-groundzero.svg \
	out/256/quake3.png \
	out/256/quake3-team-arena.png \
	out/quake4.svg \
	out/48/quake3.png \
	out/48/quake3-team-arena.png \
	$(patsubst %,out/%/quake.png,$(quake_layer_sizes)) \
	$(patsubst %,out/%/quake-armagon.png,$(quake_layer_sizes)) \
	$(patsubst %,out/%/quake-dissolution.png,$(quake_layer_sizes)) \
	$(patsubst %,out/%/quake2.png,$(quake_layer_sizes)) \
	$(patsubst %,out/%/quake2-reckoning.png,$(quake_layer_sizes)) \
	$(patsubst %,out/%/quake2-groundzero.png,$(quake_layer_sizes)) \
	$(patsubst %,out/%/quake4.png,$(quake_layer_sizes)) \
	$(NULL)

all: $(png) $(svgz) $(json_from_data) $(launcher_json) \
      $(copyright) $(dot_in) $(desktop) $(quake_icons) \
      out/bash_completion out/changelog.gz \
      out/game-data-packager out/vfs.zip out/memento-mori-2.svg

configure.mk: configure game_data_packager/version.py
	./config.status

out/CACHEDIR.TAG:
	@mkdir -p out
	( echo "Signature: 8a477f597d28d17""2789f06886806bc55"; \
	echo "# This file marks this directory to not be backed up."; \
	echo "# For information about cache directory tags, see:"; \
	echo "#	http://www.brynosaurus.com/cachedir/" ) > $@

$(copyright) $(dot_in): out/%: data/% out/CACHEDIR.TAG
	if [ -L $< ]; then cp -a $< $@ ; else install -m644 $< $@ ; fi

$(json_from_data): out/vfs/%.json: data/%.yaml tools/compile_yaml.py out/CACHEDIR.TAG
	@mkdir -p out/vfs
	$(PYTHON) tools/compile_yaml.py $< $@

out/vfs.zip: $(json_from_data)
	rm -f out/vfs.zip
	chmod 0644 out/vfs/*
	if [ -n "$(BUILD_DATE)" ]; then \
		touch --date='$(BUILD_DATE)' out/vfs/*; \
	fi
	cd out/vfs && ls -1 | LC_ALL=C sort | \
		env TZ=UTC zip ../vfs.zip -9 -X -q -@

out/bash_completion: $(in_yaml) out/CACHEDIR.TAG
	$(PYTHON) tools/bash_completion.py > ./out/bash_completion
	chmod 0644 ./out/bash_completion

out/changelog.gz: debian/changelog out/CACHEDIR.TAG
	gzip -nc9 debian/changelog > ./out/changelog.gz
	chmod 0644 ./out/changelog.gz

out/game-data-packager: run out/CACHEDIR.TAG
	install run out/game-data-packager

$(simplified_svg): out/%.svg: data/%.svg out/CACHEDIR.TAG
	inkscape --export-plain-svg=$@ $<

out/memento-mori.svg: data/memento-mori-2.svg out/CACHEDIR.TAG
	inkscape --export-plain-svg=$@ --export-id=layer1 --export-id-only $<

out/memento-mori.png: out/memento-mori.svg
	inkscape --export-png=$@ -w96 -h96 $<

$(png_from_xpm): out/%.png: data/%.xpm out/CACHEDIR.TAG
	convert $< $@

$(png_from_svg): out/%.png: data/%.svg out/CACHEDIR.TAG
	inkscape --export-png=$@ -w96 -h96 $<

$(svgz): out/%.svgz: out/%.svg
	gzip -nc $< > $@

out/quake.svg: data/quake1+2.svg out/CACHEDIR.TAG
	xmlstarlet ed -d "//*[local-name() = 'g' and @inkscape:groupmode = 'layer' and @id != 'layer-quake-256']" < $< > out/tmp/quake.svg
	inkscape \
		--export-area-page \
		--export-plain-svg=$@ \
		out/tmp/quake.svg
	rm -f out/tmp/quake.svg

out/quake-%.svg: out/tmp/recolour-%.svg out/CACHEDIR.TAG
	xmlstarlet ed -d "//*[local-name() = 'g' and @inkscape:groupmode = 'layer' and @id != 'layer-quake-256']" < $< > out/tmp/quake-$*.svg
	inkscape \
		--export-area-page \
		--export-plain-svg=$@ \
		out/tmp/quake-$*.svg
	rm -f out/tmp/quake-$*.svg

out/quake2.svg: data/quake1+2.svg out/CACHEDIR.TAG
	xmlstarlet ed -d "//*[local-name() = 'g' and @inkscape:groupmode = 'layer' and @id != 'layer-quake2-256']" < $< > out/tmp/quake2.svg
	inkscape \
		--export-area-page \
		--export-plain-svg=$@ \
		out/tmp/quake2.svg
	rm -f out/tmp/quake2.svg

out/quake4.svg: data/quake1+2.svg out/CACHEDIR.TAG
	xmlstarlet ed -d "//*[local-name() = 'g' and @inkscape:groupmode = 'layer' and @id != 'layer-quake4-256']" < $< > out/tmp/quake4.svg
	inkscape \
		--export-area-page \
		--export-plain-svg=$@ \
		out/tmp/quake4.svg
	rm -f out/tmp/quake4.svg

out/quake2-%.svg: out/tmp/recolour-%.svg out/CACHEDIR.TAG
	xmlstarlet ed -d "//*[local-name() = 'g' and @inkscape:groupmode = 'layer' and @id != 'layer-quake2-256']" < $< > out/tmp/quake2-$*.svg
	inkscape \
		--export-area-page \
		--export-plain-svg=$@ \
		out/tmp/quake2-$*.svg
	rm -f out/tmp/quake2-$*.svg

out/256/quake3.png: data/quake3-tango.xcf out/CACHEDIR.TAG
	install -d out/256
	xcf2png -o $@ $<

out/256/quake3-team-arena.png: data/quake3-teamarena-tango.xcf out/CACHEDIR.TAG
	install -d out/256
	xcf2png -o $@ $<

out/48/quake3.png: out/256/quake3.png out/CACHEDIR.TAG
	install -d out/48
	convert -resize 48x48 $< $@

out/48/quake3-team-arena.png: out/256/quake3-team-arena.png out/CACHEDIR.TAG
	install -d out/48
	convert -resize 48x48 $< $@

out/tmp/recolour-dissolution.svg: data/quake1+2.svg Makefile out/CACHEDIR.TAG
	install -d out/tmp
	sed -e 's/#c17d11/#999984/' \
		-e 's/#d5b582/#dede95/' \
		-e 's/#5f3b01/#403f31/' \
		-e 's/#e9b96e/#dede95/' \
		< $< > $@

out/tmp/recolour-armagon.svg: data/quake1+2.svg Makefile out/CACHEDIR.TAG
	install -d out/tmp
	sed -e 's/#c17d11/#565248/' \
		-e 's/#d5b582/#aba390/' \
		-e 's/#5f3b01/#000000/' \
		-e 's/#e9b96e/#aba390/' \
		< $< > $@

out/tmp/recolour-reckoning.svg: data/quake1+2.svg Makefile out/CACHEDIR.TAG
	install -d out/tmp
	sed -e 's/#3a5a1e/#999984/' \
		-e 's/#73ae3a/#eeeeec/' \
		-e 's/#8ae234/#eeeeec/' \
		-e 's/#132601/#233436/' \
		< $< > $@

out/tmp/recolour-groundzero.svg: data/quake1+2.svg Makefile out/CACHEDIR.TAG
	install -d out/tmp
	sed -e 's/#3a5a1e/#ce5c00/' \
		-e 's/#73ae3a/#fce94f/' \
		-e 's/#8ae234/#fce94f/' \
		-e 's/#132601/#cc0000/' \
		< $< > $@

out/24/quake.png: out/22/quake.png out/CACHEDIR.TAG
	install -d out/24
	convert -bordercolor Transparent -border 1x1 $< $@

out/24/quake-%.png: out/22/quake-%.png out/CACHEDIR.TAG
	install -d out/24
	convert -bordercolor Transparent -border 1x1 $< $@

out/24/quake2.png: out/22/quake2.png out/CACHEDIR.TAG
	install -d out/24
	convert -bordercolor Transparent -border 1x1 $< $@

out/24/quake4.png: out/22/quake4.png out/CACHEDIR.TAG
	install -d out/24
	convert -bordercolor Transparent -border 1x1 $< $@

out/24/quake2-%.png: out/22/quake2-%.png out/CACHEDIR.TAG
	install -d out/24
	convert -bordercolor Transparent -border 1x1 $< $@

$(patsubst %,out/%/quake.png,$(quake_layer_sizes)): out/%/quake.png: data/quake1+2.svg out/CACHEDIR.TAG
	install -d out/$*
	inkscape \
		--export-area=0:0:$*:$* \
		--export-width=$* \
		--export-height=$* \
		--export-id=layer-quake-$* \
		--export-id-only \
		--export-png=$@ \
		$<

$(patsubst %,out/%/quake-armagon.png,$(quake_layer_sizes)): out/%/quake-armagon.png: out/tmp/recolour-armagon.svg out/CACHEDIR.TAG
	install -d out/$*
	inkscape \
		--export-area=0:0:$*:$* \
		--export-width=$* \
		--export-height=$* \
		--export-id=layer-quake-$* \
		--export-id-only \
		--export-png=$@ \
		$<

$(patsubst %,out/%/quake-dissolution.png,$(quake_layer_sizes)): out/%/quake-dissolution.png: out/tmp/recolour-dissolution.svg out/CACHEDIR.TAG
	install -d out/$*
	inkscape \
		--export-area=0:0:$*:$* \
		--export-width=$* \
		--export-height=$* \
		--export-id=layer-quake-$* \
		--export-id-only \
		--export-png=$@ \
		$<

$(patsubst %,out/%/quake2.png,$(quake_layer_sizes)): out/%/quake2.png: data/quake1+2.svg out/CACHEDIR.TAG
	install -d out/$*
	inkscape \
		--export-area=0:0:$*:$* \
		--export-width=$* \
		--export-height=$* \
		--export-id=layer-quake2-$* \
		--export-id-only \
		--export-png=$@ \
		$<

$(patsubst %,out/%/quake4.png,16 22 32): out/%/quake4.png: data/quake1+2.svg out/CACHEDIR.TAG
	install -d out/$*
	inkscape \
		--export-area=0:0:32:32 \
		--export-width=$* \
		--export-height=$* \
		--export-id=layer-quake4-32 \
		--export-id-only \
		--export-png=$@ \
		$<

$(patsubst %,out/%/quake4.png,48 256): out/%/quake4.png: data/quake1+2.svg out/CACHEDIR.TAG
	install -d out/$*
	inkscape \
		--export-area=0:0:$*:$* \
		--export-width=$* \
		--export-height=$* \
		--export-id=layer-quake4-$* \
		--export-id-only \
		--export-png=$@ \
		$<

$(patsubst %,out/%/quake2-reckoning.png,$(quake_layer_sizes)): out/%/quake2-reckoning.png: out/tmp/recolour-reckoning.svg out/CACHEDIR.TAG
	install -d out/$*
	inkscape \
		--export-area=0:0:$*:$* \
		--export-width=$* \
		--export-height=$* \
		--export-id=layer-quake2-$* \
		--export-id-only \
		--export-png=$@ \
		$<

$(patsubst %,out/%/quake2-groundzero.png,$(quake_layer_sizes)): out/%/quake2-groundzero.png: out/tmp/recolour-groundzero.svg out/CACHEDIR.TAG
	install -d out/$*
	inkscape \
		--export-area=0:0:$*:$* \
		--export-width=$* \
		--export-height=$* \
		--export-id=layer-quake2-$* \
		--export-id-only \
		--export-png=$@ \
		$<

$(launcher_json): out/launch-%.json: out/launch-%.yaml
	$(PYTHON) tools/yaml2json.py $< $@

$(desktop) $(patsubst %.json,%.yaml,$(launcher_json)): out/%: runtime/%.in out/CACHEDIR.TAG
	PYTHONPATH=. $(PYTHON) tools/expand_vars.py $< $@

clean:
	rm -fr out
	rm -rf game_data_packager/__pycache__
	rm -rf game_data_packager/games/__pycache__
	rm -rf tools/__pycache__

distclean: clean
	rm -f configure.mk config.status

check:
	LC_ALL=C $(PYFLAKES3) game_data_packager/*.py game_data_packager/*/*.py runtime/*.py tests/*.py tools/*.py || :
	LC_ALL=C GDP_UNINSTALLED=1 PYTHONPATH=. $(PYTHON) tests/deb.py
	LC_ALL=C GDP_UNINSTALLED=1 PYTHONPATH=. $(PYTHON) tests/hashed_file.py
	LC_ALL=C GDP_UNINSTALLED=1 PYTHONPATH=. $(PYTHON) tests/integration.py
	LC_ALL=C GDP_UNINSTALLED=1 PYTHONPATH=. $(PYTHON) tests/rpm.py
	LC_ALL=C GDP_UNINSTALLED=1 PYTHONPATH=. $(PYTHON) tests/umod.py
	LC_ALL=C GDP_UNINSTALLED=1 PYTHONPATH=. $(PYTHON) tools/check_syntax.py
	LC_ALL=C GDP_UNINSTALLED=1 PYTHONPATH=. $(PYTHON) tools/check_equivalence.py

install:
	mkdir -p $(DESTDIR)$(bindir)
	install -m0755 out/game-data-packager                  $(DESTDIR)$(bindir)/${program_prefix}game-data-packager

	mkdir -p $(DESTDIR)$(pkgdatadir)
	cp -ar game_data_packager/                             $(DESTDIR)$(pkgdatadir)/
	install -m0644 out/version.py                          $(DESTDIR)$(pkgdatadir)/game_data_packager/
	install -m0644 out/*.copyright                         $(DESTDIR)$(pkgdatadir)/
	install -m0644 out/*.png                               $(DESTDIR)$(pkgdatadir)/
	install -m0644 data/*.png                              $(DESTDIR)$(pkgdatadir)/
	install -m0644 out/*.preinst.in                        $(DESTDIR)$(pkgdatadir)/
	install -m0644 out/*.svgz                              $(DESTDIR)$(pkgdatadir)/
	install -m0644 out/bash_completion                     $(DESTDIR)$(pkgdatadir)/
	install -m0644 out/changelog.gz                        $(DESTDIR)$(pkgdatadir)/
	install -m0644 out/copyright                           $(DESTDIR)$(pkgdatadir)/
	install -m0644 out/vfs.zip                             $(DESTDIR)$(pkgdatadir)/

	install -d                                             $(DESTDIR)$(runtimedir)/
	install runtime/gdp_launcher_base.py                   $(DESTDIR)$(runtimedir)/
	install -m0644 out/version.py                          $(DESTDIR)$(runtimedir)/gdp_launcher_version.py
	install runtime/gdp-launcher.py                        $(DESTDIR)$(runtimedir)/gdp-launcher
	install runtime/openurl.py                             $(DESTDIR)$(runtimedir)/gdp-openurl
	install -m0644 $(launcher_desktops)                    $(DESTDIR)$(runtimedir)/
	install -m0644 runtime/confirm-binary-only.txt         $(DESTDIR)$(runtimedir)/
	install -m0644 runtime/missing-data.txt                $(DESTDIR)$(runtimedir)/
	install -m0644 $(launcher_json)                        $(DESTDIR)$(runtimedir)/
	install -d                                             $(DESTDIR)${gamedatadir}/quake/
	install -m644 out/version.py                           $(DESTDIR)${gamedatadir}/quake/gdp_launcher_version.py
	install -m755 runtime/gdp_launcher_base.py             $(DESTDIR)${gamedatadir}/quake/quake-server
	install -d                                             $(DESTDIR)${gamedatadir}/quake2/
	install -m644 out/version.py                           $(DESTDIR)${gamedatadir}/quake2/gdp_launcher_version.py
	install -m755 runtime/gdp_launcher_base.py             $(DESTDIR)${gamedatadir}/quake2/quake2-server
	install -d                                             $(DESTDIR)${gamedatadir}/quake3/
	install -m644 out/version.py                           $(DESTDIR)${gamedatadir}/quake3/gdp_launcher_version.py
	install -m755 runtime/gdp_launcher_base.py             $(DESTDIR)${gamedatadir}/quake3/quake3-server
	install -d                                             $(DESTDIR)${gamedatadir}/quake4/
	install -m644 out/version.py                           $(DESTDIR)${gamedatadir}/quake4/gdp_launcher_version.py
	install -m755 runtime/gdp_launcher_base.py             $(DESTDIR)${gamedatadir}/quake4/quake4-dedicated
	install -d                                             $(DESTDIR)${libdir}/etqw/
	install -m644 out/version.py                           $(DESTDIR)${libdir}/etqw/gdp_launcher_version.py
	install -m755 runtime/gdp_launcher_base.py             $(DESTDIR)${libdir}/etqw/etqw-dedicated
	install -d                                             $(DESTDIR)${sysconfdir}/apparmor.d/
	install -m0644 etc/apparmor.d/*                        $(DESTDIR)${sysconfdir}/apparmor.d/

	mkdir -p $(DESTDIR)${datadir}/bash-completion/completions
	install -m0644 data/bash-completion/game-data-packager $(DESTDIR)${datadir}/bash-completion/completions/
	sed -i 's#pkgdatadir=.*#pkgdatadir=$(pkgdatadir)#g' $(DESTDIR)${datadir}/bash-completion/completions/game-data-packager

	mkdir -p $(DESTDIR)${mandir}/man6/
	mkdir -p $(DESTDIR)${mandir}/fr/man6/
	install -m0644 doc/game-data-packager.6                $(DESTDIR)${mandir}/man6/
	install -m0644 doc/game-data-packager.fr.6             $(DESTDIR)${mandir}/fr/man6/game-data-packager.6

	mkdir -p $(DESTDIR)/etc/game-data-packager
	install -m0644 etc/game-data-packager.conf             $(DESTDIR)${sysconfdir}/
	install -m0644 etc/*-mirrors                           $(DESTDIR)${sysconfdir}/game-data-packager/

	mkdir -p $(DESTDIR)${datadir}/applications
	mkdir -p $(DESTDIR)${datadir}/pixmaps
	install -m0755 runtime/doom2-masterlevels.py           $(DESTDIR)$(bindir)/${program_prefix}doom2-masterlevels
	install -m0644 out/doom2-masterlevels.desktop          $(DESTDIR)${datadir}/applications/
	install -m0644 doc/doom2-masterlevels.6                $(DESTDIR)${mandir}/man6/
	install -m0644 out/doom-common.png                     $(DESTDIR)${datadir}/pixmaps/doom2-masterlevels.png
	install -d                                             $(DESTDIR)$(bindir)
	ln -s ${runtimedir}/gdp-launcher                       $(DESTDIR)$(bindir)/${program_prefix}quake
	ln -s ${gamedatadir}/quake/quake-server                $(DESTDIR)$(bindir)/${program_prefix}quake-server
	ln -s ${runtimedir}/gdp-launcher                       $(DESTDIR)$(bindir)/${program_prefix}quake2
	ln -s ${gamedatadir}/quake2/quake2-server              $(DESTDIR)$(bindir)/${program_prefix}quake2-server
	ln -s ${runtimedir}/gdp-launcher                       $(DESTDIR)$(bindir)/${program_prefix}quake3
	ln -s ${gamedatadir}/quake3/quake3-server              $(DESTDIR)$(bindir)/${program_prefix}quake3-server
	ln -s ${runtimedir}/gdp-launcher                       $(DESTDIR)$(bindir)/${program_prefix}quake4
	ln -s ${gamedatadir}/quake4/quake4-dedicated           $(DESTDIR)$(bindir)/${program_prefix}quake4-dedicated
	ln -s ${runtimedir}/gdp-launcher                       $(DESTDIR)$(bindir)/${program_prefix}etqw
	ln -s ${libdir}/etqw/etqw-dedicated                    $(DESTDIR)$(bindir)/${program_prefix}etqw-dedicated
	install -d                                             $(DESTDIR)$(datadir)/applications
	install -m644 out/etqw.desktop                         $(DESTDIR)$(datadir)/applications
	install -m644 out/quake*.desktop                       $(DESTDIR)$(datadir)/applications
	install -d                                             $(DESTDIR)$(datadir)/icons/hicolor/16x16/apps
	install -m644 out/16/*.png                             $(DESTDIR)$(datadir)/icons/hicolor/16x16/apps
	install -d                                             $(DESTDIR)$(datadir)/icons/hicolor/22x22/apps
	install -m644 out/22/*.png                             $(DESTDIR)$(datadir)/icons/hicolor/22x22/apps
	install -d                                             $(DESTDIR)$(datadir)/icons/hicolor/24x24/apps
	install -m644 out/24/*.png                             $(DESTDIR)$(datadir)/icons/hicolor/24x24/apps
	install -d                                             $(DESTDIR)$(datadir)/icons/hicolor/32x32/apps
	install -m644 out/32/*.png                             $(DESTDIR)$(datadir)/icons/hicolor/32x32/apps
	install -d                                             $(DESTDIR)$(datadir)/icons/hicolor/48x48/apps
	install -m644 out/48/*.png                             $(DESTDIR)$(datadir)/icons/hicolor/48x48/apps
	install -d                                             $(DESTDIR)$(datadir)/icons/hicolor/256x256/apps
	install -m644 out/256/*.png                            $(DESTDIR)$(datadir)/icons/hicolor/256x256/apps
	install -d                                             $(DESTDIR)$(datadir)/icons/hicolor/scalable/apps
	install -m644 out/quake*.svg                           $(DESTDIR)$(datadir)/icons/hicolor/scalable/apps
	install -m644 out/quake-*.svg                          $(DESTDIR)$(datadir)/icons/hicolor/scalable/apps
	install -m644 out/quake2*.svg                          $(DESTDIR)$(datadir)/icons/hicolor/scalable/apps
	install -m644 out/quake4*.svg                          $(DESTDIR)$(datadir)/icons/hicolor/scalable/apps
	install -d                                             $(DESTDIR)${mandir}/man6
	install -m644 doc/etqw*.6                              $(DESTDIR)${mandir}/man6
	install -m644 doc/quake*.6                             $(DESTDIR)${mandir}/man6

html: $(DIRS) $(json)
	LC_ALL=C GDP_UNINSTALLED=1 PYTHONPATH=. python3 -m tools.babel
	rsync out/index.html alioth.debian.org:/var/lib/gforge/chroot/home/groups/pkg-games/htdocs/game-data/ -e ssh -v

.PHONY: all clean distclean check install html
