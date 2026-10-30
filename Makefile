.PHONY: help build check pack dmg install uninstall reinstall open version clean

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
APP  := /Applications/Kenglit.app
PLIST := $(ROOT)/Resources/Info.plist

help:
	@echo "make build | check | pack | dmg | install | uninstall | reinstall | open | version | clean"

build:
	cd $(ROOT) && swift build --product Kenglit

check:
	cd $(ROOT) && swift build --product KenglitCoreChecks
	$(ROOT)/.build/debug/KenglitCoreChecks

pack:
	$(ROOT)/Scripts/pack-app.sh

dmg:
	$(ROOT)/Scripts/pack-dmg.sh

install:
	$(ROOT)/Scripts/install.sh

uninstall:
	$(ROOT)/Scripts/uninstall-all.sh

reinstall:
	$(ROOT)/Scripts/reinstall.sh

open:
	open $(APP)

version:
	@echo "CFBundleShortVersionString=$$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' $(PLIST))"
	@echo "CFBundleVersion=$$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' $(PLIST))"
	@echo "CFBundleIdentifier=$$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' $(PLIST))"
	@echo "LSMinimumSystemVersion=$$(/usr/libexec/PlistBuddy -c 'Print LSMinimumSystemVersion' $(PLIST))"
	@if [ -d "$(APP)" ]; then \
	  echo "installed=$(APP)"; \
	  echo "installed_version=$$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' $(APP)/Contents/Info.plist)"; \
	else \
	  echo "installed=(none)"; \
	fi

clean:
	@stamp=$$(date +%Y%m%d%H%M%S); \
	if [ -d "$(ROOT)/.build" ]; then \
	  mv "$(ROOT)/.build" "/tmp/kenglit-build-$$stamp"; \
	  echo "moved .build -> /tmp/kenglit-build-$$stamp"; \
	else \
	  echo "nothing to clean"; \
	fi
