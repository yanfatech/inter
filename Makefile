# Targets:
#   all               Build everything
#   test              Build and test everyything (implies all_check)
#   install           Build and install all OTF files. (currently Mac-only)
#   zip               Build a complete release-grade ZIP archive of all fonts.
#   dist              Create a new release distribution. Does everything.
#
#   all_const         Build all non-variable files
#   all_const_hinted  Build all non-variable files with hints
#   all_var           Build all variable files
#   all_var_hinted    Build all variable files with hints (disabled)
#
#   all_otf					  Build all OTF files into FONTDIR/const
#   all_ttf					  Build all TTF files into FONTDIR/const
#   all_ttf_hinted	  Build all TTF files with hints into FONTDIR/const-hinted
#   all_web					  Build all WOFF files into FONTDIR/const
#   all_web_hinted	  Build all WOFF files with hints into FONTDIR/const-hinted
#   all_var           Build all variable font files into FONTDIR/var
#   all_var_hinted    Build all variable font files with hints into
#                     FONTDIR/var-hinted
#
#   designspace       Build src/Inter-UI.designspace from src/Inter-UI.glyphs
#
# Style-specific targets:
#   STYLE_otf         Build OTF file for STYLE into FONTDIR/const
#   STYLE_ttf         Build TTF file for STYLE into FONTDIR/const
#   STYLE_ttf_hinted  Build TTF file for STYLE with hints into
#                     FONTDIR/const-hinted
#   STYLE_web         Build WOFF files for STYLE into FONTDIR/const
#   STYLE_web_hinted  Build WOFF files for STYLE with hints into
#                     FONTDIR/const-hinted
#   STYLE_check       Build & check OTF and TTF files for STYLE
#
# "build" directory output structure:
# 	fonts
# 		const
# 		const-hinted
# 		var
# 		var-hinted  (disabled)
#
FONTDIR = build/fonts

all: all_const  all_const_hinted  all_var

all_const: all_otf  all_ttf  all_web
all_const_hinted: all_ttf_hinted  all_web_hinted
all_var: \
	$(FONTDIR)/var/Inter-UI.var.woff2 \
	$(FONTDIR)/var/Inter-UI-upright.var.woff2 \
	$(FONTDIR)/var/Inter-UI-italic.var.woff2 \
	$(FONTDIR)/var/Inter-UI.var.ttf \
	$(FONTDIR)/var/Inter-UI-upright.var.ttf \
	$(FONTDIR)/var/Inter-UI-italic.var.ttf

# Disabled. See https://github.com/rsms/inter/issues/75
# all_var_hinted: $(FONTDIR)/var-hinted/Inter-UI.var.ttf $(FONTDIR)/var-hinted/Inter-UI.var.woff2
# .PHONY: all_var_hinted

.PHONY: all_const  all_const_hinted  all_var

export PATH := $(PWD)/build/venv/bin:$(PATH)

# generated.make is automatically generated by init.sh and defines depenencies for
# all styles and alias targets
include build/etc/generated.make


# TTF -> WOFF2
build/%.woff2: build/%.ttf
	woff2_compress "$<"

# TTF -> WOFF
build/%.woff: build/%.ttf
	ttf2woff -O -t woff "$<" "$@"

# make sure intermediate TTFs are not gc'd by make
.PRECIOUS: build/%.ttf

# TTF -> EOT (disabled)
# build/%.eot: build/%.ttf
# 	ttf2eot "$<" > "$@"


# Master UFO -> OTF, TTF

all_ufo_masters = $(Regular_ufo_d) $(Black_ufo_d) $(Italic_ufo_d) $(BlackItalic_ufo_d)

$(FONTDIR)/var/%.var.ttf: src/%.designspace $(all_ufo_masters)
	misc/fontbuild compile-var -o $@ $<

$(FONTDIR)/const/Inter-UI-Regular.%: src/Inter-UI.designspace $(Regular_ufo_d)
	misc/fontbuild compile -o $@ src/Inter-UI-Regular.ufo

$(FONTDIR)/const/Inter-UI-Black.%: src/Inter-UI.designspace $(Black_ufo_d)
	misc/fontbuild compile -o $@ src/Inter-UI-Black.ufo

$(FONTDIR)/const/Inter-UI-Italic.%: src/Inter-UI.designspace $(Italic_ufo_d)
	misc/fontbuild compile -o $@ src/Inter-UI-Italic.ufo

$(FONTDIR)/const/Inter-UI-BlackItalic.%: src/Inter-UI.designspace $(BlackItalic_ufo_d)
	misc/fontbuild compile -o $@ src/Inter-UI-BlackItalic.ufo

# Instance UFO -> OTF, TTF

$(FONTDIR)/const/Inter-UI-%.otf: build/ufo/Inter-UI-%.ufo src/Inter-UI.designspace $(all_ufo_masters)
	misc/fontbuild compile -o $@ $<

$(FONTDIR)/const/Inter-UI-%.ttf: build/ufo/Inter-UI-%.ufo src/Inter-UI.designspace $(all_ufo_masters)
	misc/fontbuild compile -o $@ $<


# designspace <- glyphs file
src/Inter-UI.designspace: src/Inter-UI.glyphs
	misc/fontbuild glyphsync $<

designspace: src/Inter-UI.designspace
.PHONY: designspace

# short-circuit Make for performance
src/Inter-UI.glyphs:
	@true

# instance UFOs <- master UFOs
build/ufo/Inter-UI-%.ufo: src/Inter-UI.designspace $(Regular_ufo_d) $(Black_ufo_d)
	misc/fontbuild instancegen src/Inter-UI.designspace $*

# make sure intermediate UFOs are not gc'd by make
.PRECIOUS: build/ufo/Inter-UI-%.ufo

# Note: The seemingly convoluted dependency graph above is required to
# make sure that glyphsync and instancegen are not run in parallel.


# hinted TTF files via autohint
$(FONTDIR)/const-hinted/%.ttf: $(FONTDIR)/const/%.ttf
	mkdir -p "$(dir $@)"
	ttfautohint --fallback-stem-width=256 --no-info --composites "$<" "$@"

# $(FONTDIR)/var-hinted/%.ttf: $(FONTDIR)/var/%.ttf
# 	mkdir -p "$(dir $@)"
# 	ttfautohint --fallback-stem-width=256 --no-info --composites "$<" "$@"

# make sure intermediate TTFs are not gc'd by make
.PRECIOUS: $(FONTDIR)/const/%.ttf $(FONTDIR)/const-hinted/%.ttf $(FONTDIR)/var/%.var.ttf

# check var
all_check_var: $(FONTDIR)/var/Inter-UI.var.ttf
	misc/fontbuild checkfont $^

# test runs all tests
# Note: all_check_const is generated by init.sh and runs "fontbuild checkfont"
# on all otf and ttf files.
test: all_check_const  all_check_var

# load version, used by zip and dist
VERSION := $(shell cat version.txt)

# distribution zip files
ZIP_FILE_DIST := build/release/Inter-UI-${VERSION}.zip
ZIP_FILE_DEV  := build/release/Inter-UI-${VERSION}-$(shell git rev-parse --short=10 HEAD).zip

ZD = build/tmp/zip
# intermediate zip target that creates a zip file at build/tmp/a.zip
build/tmp/a.zip: all
	@rm -rf "$(ZD)"
	@rm -f  build/tmp/a.zip
	@mkdir -p \
	  "$(ZD)/Inter UI (web)" \
	  "$(ZD)/Inter UI (web hinted)" \
	  "$(ZD)/Inter UI (TTF)" \
	  "$(ZD)/Inter UI (TTF hinted)" \
	  "$(ZD)/Inter UI (TTF variable)" \
	  "$(ZD)/Inter UI (OTF)"
	  # "$(ZD)/Inter UI (TTF variable hinted)"
	# copy font files
	cp -a $(FONTDIR)/const/*.woff \
	      $(FONTDIR)/const/*.woff2 \
	      $(FONTDIR)/var/*.woff2        "$(ZD)/Inter UI (web)/"
	# cp -a $(FONTDIR)/const-hinted/*.woff \
	#       $(FONTDIR)/const-hinted/*.woff2 \
	#       $(FONTDIR)/var-hinted/*.woff2 "$(ZD)/Inter UI (web hinted)/"
	cp -a $(FONTDIR)/const-hinted/*.woff \
	      $(FONTDIR)/const-hinted/*.woff2 \
	      													    "$(ZD)/Inter UI (web hinted)/"
	cp -a $(FONTDIR)/const/*.ttf        "$(ZD)/Inter UI (TTF)/"
	cp -a $(FONTDIR)/const-hinted/*.ttf "$(ZD)/Inter UI (TTF hinted)/"
	cp -a $(FONTDIR)/var/*.ttf          "$(ZD)/Inter UI (TTF variable)/"
	# cp -a $(FONTDIR)/var-hinted/*.ttf   "$(ZD)/Inter UI (TTF variable hinted)/"
	cp -a $(FONTDIR)/const/*.otf        "$(ZD)/Inter UI (OTF)/"
	# copy misc stuff
	cp -a misc/dist/inter-ui.css        "$(ZD)/Inter UI (web)/"
	cp -a misc/dist/inter-ui.css        "$(ZD)/Inter UI (web hinted)/"
	cp -a misc/dist/*.txt               "$(ZD)/"
	cp -a LICENSE.txt                   "$(ZD)/"
	# zip
	cd $(ZD) && zip -q -X -r "../../../$@" * && cd ../..
	@rm -rf $(ZD)

# zip
build/release/Inter-UI-%.zip: build/tmp/a.zip
	@mkdir -p "$(shell dirname "$@")"
	@mv -f "$<" "$@"
	@echo write "$@"
	@sh -c "if [ -f /usr/bin/open ]; then /usr/bin/open --reveal '$@'; fi"

zip: ${ZIP_FILE_DEV}
zip_dist: pre_dist test ${ZIP_FILE_DIST}
.PHONY: zip zip_dist

# distribution
pre_dist:
	@echo "Creating distribution for version ${VERSION}"
	@if [ -f "${ZIP_FILE_DIST}" ]; \
		then echo "${ZIP_FILE_DIST} already exists. Bump version or remove the zip file to continue." >&2; \
		exit 1; \
  fi

dist: zip_dist  docs
	misc/tools/versionize-css.py
	@echo "——————————————————————————————————————————————————————————————————"
	@echo ""
	@echo "Next steps:"
	@echo ""
	@echo "1) Commit & push changes"
	@echo ""
	@echo "2) Create new release with ${ZIP_FILE_DIST} at"
	@echo "   https://github.com/rsms/inter/releases/new?tag=v${VERSION}"
	@echo ""
	@echo "3) Bump version in version.txt (to the next future version)"
	@echo ""
	@echo "——————————————————————————————————————————————————————————————————"

docs: docs_fonts
	$(MAKE) -j docs_info

docs_info: docs/_data/fontinfo.json docs/lab/glyphinfo.json docs/glyphs/metrics.json

docs_fonts:
	rm -rf docs/font-files
	mkdir docs/font-files
	cp -a $(FONTDIR)/const/*.woff \
	      $(FONTDIR)/const/*.woff2 \
	      $(FONTDIR)/const/*.otf \
	      $(FONTDIR)/var/*.* \
	      docs/font-files/

.PHONY: docs docs_info docs_fonts

docs/_data/fontinfo.json: docs/font-files/Inter-UI-Regular.otf misc/tools/fontinfo.py
	misc/tools/fontinfo.py -pretty $< > docs/_data/fontinfo.json

docs/lab/glyphinfo.json: build/UnicodeData.txt misc/tools/gen-glyphinfo.py $(all_ufo_masters)
	misc/tools/gen-glyphinfo.py -ucd $< src/Inter-UI-*.ufo > $@

docs/glyphs/metrics.json: $(Regular_ufo_d) misc/tools/gen-metrics-and-svgs.py
	misc/tools/gen-metrics-and-svgs.py src/Inter-UI-Regular.ufo

# Download latest Unicode data
build/UnicodeData.txt:
	@echo fetch http://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt
	@curl '-#' -o "$@" http://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt


# install targets
install_ttf: all_ttf_const
	$(MAKE) all_web -j
	@echo "Installing TTF files locally at ~/Library/Fonts/Inter UI"
	rm -rf ~/'Library/Fonts/Inter UI'
	mkdir -p ~/'Library/Fonts/Inter UI'
	cp -va $(FONTDIR)/const/*.ttf ~/'Library/Fonts/Inter UI'

install_ttf_hinted: all_ttf
	$(MAKE) all_web -j
	@echo "Installing autohinted TTF files locally at ~/Library/Fonts/Inter UI"
	rm -rf ~/'Library/Fonts/Inter UI'
	mkdir -p ~/'Library/Fonts/Inter UI'
	cp -va $(FONTDIR)/const-hinted/*.ttf ~/'Library/Fonts/Inter UI'

install_otf: all_otf
	$(MAKE) all_web -j
	@echo "Installing OTF files locally at ~/Library/Fonts/Inter UI"
	rm -rf ~/'Library/Fonts/Inter UI'
	mkdir -p ~/'Library/Fonts/Inter UI'
	cp -va $(FONTDIR)/const/*.otf ~/'Library/Fonts/Inter UI'

install: install_otf

# clean removes generated and built fonts in the build directory
clean:
	rm -rvf build/tmp build/fonts

.PHONY: all web clean install install_otf install_ttf deploy pre_dist dist geninfo test glyphsync
