APP := build/Sharer's Bible App.app
DMG := build/Sharer's Bible App.dmg
EXEC := $(APP)/Contents/MacOS/Sharer's Bible App
RES  := $(APP)/Contents/Resources
BIB  := $(abspath ../bibles)

SDK := $(shell xcrun --sdk macosx --show-sdk-path)

.PHONY: all build clean dmg

all: dmg

build:
	@mkdir -p "$(APP)/Contents/MacOS" "$(RES)"
	xcrun swiftc -sdk "$(SDK)" -parse-as-library \
		-o "$(EXEC)" \
		-Xlinker -rpath -Xlinker /usr/lib/swift \
		ContentView.swift
	cp -R "$(BIB)" "$(RES)/bibles"
	@echo "=== Build complete ==="

dmg: build
	@rm -rf build/dmg-tmp "$(DMG)"
	@mkdir -p build/dmg-tmp
	@cp -R "$(APP)" build/dmg-tmp/
	@ln -s /Applications build/dmg-tmp/Applications
	@set -e; \
	VOL="Sharer's Bible"; \
	SRC="build/dmg-tmp"; \
	DST="$(DMG)"; \
	SZ=$$(du -sm "$$SRC" | cut -f1); \
	SZ=$$((SZ + 15)); \
	hdiutil create -fs HFS+ -srcfolder "$$SRC" -volname "$$VOL" \
		-format UDZO -imagekey zlib-level=9 -size $${SZ}m "$$DST"
	@rm -rf build/dmg-tmp
	@echo "=== Created $(DMG) ==="

clean:
	rm -rf build
