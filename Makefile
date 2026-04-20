# Use bash for `<<<` herestrings in the version-bump recipes.
SHELL := /bin/bash

# Load signing/notarization secrets from .env if present.
# File is in Make syntax: KEY = value (no quotes, value can contain spaces).
# See .env.example.
-include .env

# Defaults — override any of these in .env.
APP_NAME      ?= ScreenPresenter
DISPLAY_NAME  ?= Screen Presenter
BUNDLE_ID     ?= com.epatel.ScreenPresenter
VERSION       := $(shell cat VERSION)

BUILD_DIR     := build
RELEASE_BIN   := .build/release/$(APP_NAME)
APP_BUNDLE    := $(BUILD_DIR)/$(APP_NAME).app
ICON_SRC      := icon.png
ICONSET       := $(BUILD_DIR)/$(APP_NAME).iconset
ICNS          := $(BUILD_DIR)/AppIcon.icns
ZIP           := $(BUILD_DIR)/$(APP_NAME)-$(VERSION).zip
DMG           := $(BUILD_DIR)/$(APP_NAME)-$(VERSION).dmg

# Required for sign / notarize. Provide via env or a .env file you source.
#   SIGNING_IDENTITY         e.g. "Developer ID Application: Your Name (TEAMID)"
#   APPLE_ID             your Apple ID email
#   TEAM_ID        10-char team ID
#   APP_PASSWORD   app-specific password
SIGNING_IDENTITY        ?=
APPLE_ID            ?=
TEAM_ID       ?=
APP_PASSWORD  ?=

.PHONY: help version build release run app icon sign verify zip notarize staple dmg open clean \
        bump-patch bump-minor bump-major

.DEFAULT_GOAL := help

help:
	@echo "Targets:"
	@echo "  build       swift build (debug)"
	@echo "  release     swift build -c release"
	@echo "  run         swift run"
	@echo "  icon        build $(ICNS) from $(ICON_SRC)"
	@echo "  app         build the .app bundle at $(APP_BUNDLE)"
	@echo "  sign        codesign the bundle with hardened runtime"
	@echo "  verify      verify signature and hardened runtime"
	@echo "  zip         zip the signed bundle for notarization"
	@echo "  notarize    submit to Apple notary service (waits)"
	@echo "  staple      staple the notarization ticket"
	@echo "  dmg         build a distribution .dmg"
	@echo "  open        open the built .app"
	@echo "  clean       remove build artifacts"
	@echo "  version     print VERSION"
	@echo "  bump-patch  VERSION +0.0.1"
	@echo "  bump-minor  VERSION +0.1.0 and zero patch"
	@echo "  bump-major  VERSION +1.0.0 and zero minor/patch"

version:
	@echo $(VERSION)

build:
	swift build

release:
	swift build -c release

run:
	swift run

# ---------- Icon ----------

icon: $(ICNS)

$(ICNS): $(ICON_SRC)
	@if [ ! -f "$(ICON_SRC)" ]; then \
		echo "error: $(ICON_SRC) not found (provide a 1024x1024 PNG)"; exit 1; \
	fi
	@mkdir -p $(BUILD_DIR)
	rm -rf $(ICONSET)
	mkdir -p $(ICONSET)
	sips -z 16 16     $(ICON_SRC) --out $(ICONSET)/icon_16x16.png       >/dev/null
	sips -z 32 32     $(ICON_SRC) --out $(ICONSET)/icon_16x16@2x.png    >/dev/null
	sips -z 32 32     $(ICON_SRC) --out $(ICONSET)/icon_32x32.png       >/dev/null
	sips -z 64 64     $(ICON_SRC) --out $(ICONSET)/icon_32x32@2x.png    >/dev/null
	sips -z 128 128   $(ICON_SRC) --out $(ICONSET)/icon_128x128.png     >/dev/null
	sips -z 256 256   $(ICON_SRC) --out $(ICONSET)/icon_128x128@2x.png  >/dev/null
	sips -z 256 256   $(ICON_SRC) --out $(ICONSET)/icon_256x256.png     >/dev/null
	sips -z 512 512   $(ICON_SRC) --out $(ICONSET)/icon_256x256@2x.png  >/dev/null
	sips -z 512 512   $(ICON_SRC) --out $(ICONSET)/icon_512x512.png     >/dev/null
	sips -z 1024 1024 $(ICON_SRC) --out $(ICONSET)/icon_512x512@2x.png  >/dev/null
	iconutil -c icns $(ICONSET) -o $(ICNS)
	rm -rf $(ICONSET)

# ---------- Bundle ----------

app: release $(ICNS)
	@echo "Building $(APP_BUNDLE) v$(VERSION)"
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(RELEASE_BIN) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp $(ICNS) $(APP_BUNDLE)/Contents/Resources/AppIcon.icns
	@sed -e 's/__VERSION__/$(VERSION)/g' \
	     -e 's/__BUNDLE_ID__/$(BUNDLE_ID)/g' \
	     -e 's/__EXECUTABLE__/$(APP_NAME)/g' \
	     -e 's/__NAME__/$(APP_NAME)/g' \
	     Resources/Info.plist.template > $(APP_BUNDLE)/Contents/Info.plist
	@# Bundle the default deck so the app has something to show when no path is passed.
	@if [ -f sample.md ]; then cp sample.md $(APP_BUNDLE)/Contents/Resources/; fi
	@if [ -d images ]; then cp -R images $(APP_BUNDLE)/Contents/Resources/; fi

# ---------- Sign ----------

sign: app
	@if [ -z "$(SIGNING_IDENTITY)" ]; then \
		echo "error: SIGNING_IDENTITY not set (e.g. 'Developer ID Application: Your Name (TEAMID)')"; exit 1; \
	fi
	codesign --force --deep --options runtime --timestamp \
		--entitlements Resources/entitlements.plist \
		--sign "$(SIGNING_IDENTITY)" \
		$(APP_BUNDLE)

verify:
	codesign --verify --deep --strict --verbose=2 $(APP_BUNDLE)
	codesign --display --verbose=2 $(APP_BUNDLE) 2>&1 | grep -E '(Authority|Runtime|flags)'
	spctl --assess --type execute --verbose=4 $(APP_BUNDLE) || true

# ---------- Notarize ----------

zip: sign
	rm -f $(ZIP)
	ditto -c -k --keepParent $(APP_BUNDLE) $(ZIP)
	@echo "Wrote $(ZIP)"

notarize: zip
	@if [ -z "$(APPLE_ID)" ] || [ -z "$(TEAM_ID)" ] || [ -z "$(APP_PASSWORD)" ]; then \
		echo "error: APPLE_ID, TEAM_ID, APP_PASSWORD must be set"; exit 1; \
	fi
	xcrun notarytool submit $(ZIP) \
		--apple-id "$(APPLE_ID)" \
		--team-id "$(TEAM_ID)" \
		--password "$(APP_PASSWORD)" \
		--wait

staple:
	xcrun stapler staple $(APP_BUNDLE)
	xcrun stapler validate $(APP_BUNDLE)

# ---------- DMG ----------

dmg: staple
	rm -f $(DMG)
	hdiutil create -volname "$(DISPLAY_NAME) $(VERSION)" \
		-srcfolder $(APP_BUNDLE) \
		-ov -format UDZO \
		$(DMG)
	@echo "Wrote $(DMG)"

# ---------- Convenience ----------

open: app
	open $(APP_BUNDLE)

clean:
	rm -rf $(BUILD_DIR) .build

# ---------- Version bumps ----------

bump-patch:
	@v=$$(cat VERSION); \
	IFS=. read -r maj min pat <<< "$$v"; \
	new="$$maj.$$min.$$((pat+1))"; \
	echo "$$new" > VERSION; \
	echo "VERSION: $$v -> $$new"

bump-minor:
	@v=$$(cat VERSION); \
	IFS=. read -r maj min pat <<< "$$v"; \
	new="$$maj.$$((min+1)).0"; \
	echo "$$new" > VERSION; \
	echo "VERSION: $$v -> $$new"

bump-major:
	@v=$$(cat VERSION); \
	IFS=. read -r maj min pat <<< "$$v"; \
	new="$$((maj+1)).0.0"; \
	echo "$$new" > VERSION; \
	echo "VERSION: $$v -> $$new"
