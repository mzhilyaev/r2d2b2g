.PHONY: build profile prosthesis b2g run package help

-include local.mk

SYS = $(shell uname -s)
ARCH = $(shell uname -m)
ifneq (,$(findstring MINGW32_,$(SYS)))
SYS = WINNT
endif

# The type of B2G build to use.  It can be "specific", in which case you must
# set B2G_URL to the URL of the build; or "nightly", in which case you may set
# B2G_DATE to the date of the build (default: the most recent nightly build).
B2G_TYPE ?= specific

# The platform of the B2G build.
# Options include 'win32', 'mac64', 'linux64', and 'linux', and the default is
# the current platform.  The reliability of this option is unclear.  Setting it
# to 'mac64' on non-Mac is known to fail, because mozinstall doesn't know how to
# install from a DMG on a non-Mac platform.  But setting it to one of the Linux
# values on the other Linux platform works and is the main use case for it
# (i.e. to create the dual-binary Linux packages).
ifndef B2G_PLATFORM
  ifeq (WINNT, $(SYS))
    B2G_PLATFORM = win32
  else
  ifeq (Darwin, $(SYS))
    B2G_PLATFORM = mac64
  else
  ifeq (Linux, $(SYS))
    ifeq (x86_64, $(ARCH))
      B2G_PLATFORM = linux64
    else
      B2G_PLATFORM = linux
    endif
  endif
  endif
  endif
endif

# The URL of the specific B2G build.
ifeq (win32, $(B2G_PLATFORM))
  B2G_URL_BASE ?= https://ftp.mozilla.org/pub/mozilla.org/b2g/nightly/2012-12-26-07-02-02-mozilla-b2g18/
  B2G_URL ?= $(B2G_URL_BASE)b2g-18.0.multi.win32.zip
else
ifeq (mac64, $(B2G_PLATFORM))
  B2G_URL_BASE ?= https://ftp.mozilla.org/pub/mozilla.org/b2g/nightly/2012-12-26-07-02-02-mozilla-b2g18/
  B2G_URL ?= $(B2G_URL_BASE)b2g-18.0.multi.mac64.dmg
else
ifeq (linux64, $(B2G_PLATFORM))
  B2G_URL_BASE ?= https://ftp.mozilla.org/pub/mozilla.org/labs/r2d2b2g/
  B2G_URL ?= $(B2G_URL_BASE)b2g-18.0.2012-12-26.en-US.linux-x86_64.tar.bz2
else
ifeq (linux, $(B2G_PLATFORM))
  B2G_URL_BASE ?= https://ftp.mozilla.org/pub/mozilla.org/labs/r2d2b2g/
  B2G_URL ?= $(B2G_URL_BASE)b2g-18.0.2012-12-26.en-US.linux-i686.tar.bz2
endif
endif
endif
endif

# The date of the nightly B2G build.
# Sometimes this is based on the latest stable nightly for Unagi according to
# https://releases.mozilla.com/b2g/promoted_to_stable/ (private URL).
#
# Currently, we use custom builds via B2G_TYPE=specific and B2G_URL because
# nightly builds have multiple debilitating bugs, like 815805 (Linux) and 816957
# (all platforms).  Once those are fixed, we could switch back to nightlies.
#
#B2G_DATE ?= 2012-12-13

ifdef B2G_TYPE
  B2G_TYPE_ARG = --type $(B2G_TYPE)
endif

ifdef B2G_PLATFORM
  B2G_PLATFORM_ARG = --platform $(B2G_PLATFORM)
endif

ifdef B2G_URL
  B2G_URL_ARG = --url $(B2G_URL)
endif

ifdef B2G_DATE
  B2G_DATE_ARG = --date $(B2G_DATE)
endif

ifdef BIN
  BIN_ARG = -b $(BIN)
endif

ifdef TEST
  TEST_ARG = -f $(TEST)
endif

build: profile prosthesis b2g

profile:
	make -C gaia
	python build/override-settings.py
	python build/override-webapps.py
	rm -rf gaia/profile/startupCache
	rm -rf addon/template
	mkdir -p addon/template
	mv gaia/profile addon/template/
	cp addon-sdk/app-extension/bootstrap.js addon/template/
	cp addon-sdk/app-extension/install.rdf addon/template/

prosthesis: profile
	mkdir -p addon/template/profile/extensions
	cd prosthesis && zip -r b2g-prosthesis\@mozilla.org.xpi content defaults locale skin chrome.manifest install.rdf
	mv prosthesis/b2g-prosthesis@mozilla.org.xpi addon/template/profile/extensions

b2g:
	python build/make-b2g.py $(B2G_TYPE_ARG) $(B2G_PLATFORM_ARG) $(B2G_DATE_ARG) $(B2G_URL_ARG)

run:
	cd addon-sdk && . bin/activate && cd ../addon && cfx run --templatedir template/ $(BIN_ARG)

package:
	cd addon-sdk && . bin/activate && cd ../addon && cfx xpi --templatedir template/

test:
	cd addon-sdk && . bin/activate && cd ../addon && cfx test --verbose --templatedir template/ $(BIN_ARG) $(TEST_ARG)

help:
	@echo 'Targets:'
	@echo "  build: [default] build, download, install everything;\n"\
	"         combines the profile, prosthesis, and b2g make targets"
	@echo '  profile: make the Gaia profile'
	@echo '  prosthesis: make the prosthesis addon that enhances B2G'
	@echo '  b2g: download and install B2G'
	@echo '  run: start Firefox with the addon installed into a new profile'
	@echo '  package: package the addon into a XPI'
	@echo '  help: show this message'
