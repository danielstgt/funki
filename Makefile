# Funki – build the .app bundle with nothing but the Swift toolchain.
#
#   make            build build/Funki.app (universal, ad-hoc signed)
#   make run        build and launch it
#   make install    copy it to /Applications
#   make zip        build/Funki-<version>.zip for a GitHub release
#   make clean

APP        := Funki
VERSION    ?= 0.1.0
BUILD      ?= $(shell git rev-list --count HEAD 2>/dev/null || echo 1)
BUNDLE_ID  ?= io.github.danielstgt.funki
MIN_OS     := 14.0
ARCHS      ?= --arch arm64 --arch x86_64
# Ad-hoc signature by default. Pass SIGN_IDENTITY="Developer ID Application: …" to sign for distribution.
SIGN_IDENTITY ?= -
# Notarization wants a secure timestamp, and only a real identity can get one.
TIMESTAMP  := $(if $(filter -,$(SIGN_IDENTITY)),--timestamp=none,--timestamp)

BUILD_DIR  := build
APP_DIR    := $(BUILD_DIR)/$(APP).app
CONTENTS   := $(APP_DIR)/Contents
ICONSET    := $(BUILD_DIR)/AppIcon.iconset
ICNS       := $(BUILD_DIR)/AppIcon.icns

# Build the app product only. A bare `swift build` goes through SwiftPM's synthesized
# aggregate target, which has no deployment target of its own and falls back to the
# SDK's. From the macOS 27 SDK on that draws "The x86_64 architecture is deprecated for
# your deployment target", although the app itself targets macOS $(MIN_OS).
SWIFT_BUILD := swift build -c release $(ARCHS) --product $(APP)

.PHONY: all build app run install zip clean

all: app

build:
	$(SWIFT_BUILD)

$(ICNS): Scripts/generate-icon.swift
	rm -rf $(ICONSET)
	swift Scripts/generate-icon.swift $(ICONSET)
	iconutil -c icns $(ICONSET) -o $(ICNS)

# The products directory depends on the toolchain, so ask the same `swift` that built.
# The hardened runtime is always on; Funki needs no entitlements.
app: build $(ICNS)
	rm -rf $(APP_DIR)
	mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources
	cp "$$($(SWIFT_BUILD) --show-bin-path)/$(APP)" $(CONTENTS)/MacOS/$(APP)
	cp $(ICNS) $(CONTENTS)/Resources/AppIcon.icns
	sed -e 's/__VERSION__/$(VERSION)/g' -e 's/__BUILD__/$(BUILD)/g' \
	    -e 's/__BUNDLE_ID__/$(BUNDLE_ID)/g' -e 's/__MIN_OS__/$(MIN_OS)/g' \
	    Resources/Info.plist > $(CONTENTS)/Info.plist
	printf 'APPL????' > $(CONTENTS)/PkgInfo
	codesign --force --options runtime $(TIMESTAMP) --sign "$(SIGN_IDENTITY)" $(APP_DIR)
	@echo "Built $(APP_DIR) ($(VERSION))"

# `open` would only bring a running Funki to the front instead of starting the new build.
run: app
	@pkill -x $(APP) && sleep 1 || true
	open $(APP_DIR)

install: app
	rm -rf "/Applications/$(APP).app"
	cp -R $(APP_DIR) /Applications/
	@echo "Installed /Applications/$(APP).app"

zip: app
	rm -f $(BUILD_DIR)/$(APP)-$(VERSION).zip
	ditto -c -k --keepParent $(APP_DIR) $(BUILD_DIR)/$(APP)-$(VERSION).zip
	@echo "Created $(BUILD_DIR)/$(APP)-$(VERSION).zip"

clean:
	rm -rf $(BUILD_DIR) .build
