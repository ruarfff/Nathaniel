# Nathaniel - Build and Run Commands
# ===================================

# Project configuration
PROJECT := Nathaniel.xcodeproj
IOS_SCHEME := Nathaniel iOS
MACOS_SCHEME := Nathaniel macOS
BUNDLE_ID := com.ruarfff.Nathaniel

# Default simulator (override with: make ios-run SIMULATOR="iPhone 17 Pro Max")
# NOTE: This project requires iOS 26.1+, so use iPhone 17 series or newer
SIMULATOR ?= iPhone 17 Pro

# Configuration (Debug or Release)
CONFIG ?= Debug
DERIVED_DATA_PATH ?= $(CURDIR)/build/DerivedData
IOS_APP = $(DERIVED_DATA_PATH)/Build/Products/$(CONFIG)-iphonesimulator/Nathaniel.app
MACOS_APP = $(DERIVED_DATA_PATH)/Build/Products/$(CONFIG)/Nathaniel.app
DEVICE_APP = $(DERIVED_DATA_PATH)/Build/Products/$(CONFIG)-iphoneos/Nathaniel.app

.PHONY: help ios macos ios-build macos-build ios-run macos-run clean ios-clean macos-clean list-simulators shutdown-sims ios-fresh clean-derived test test-ios test-macos test-unit test-tooling lint format health stop ios-device ios-device-build list-devices

# Default target
help:
	@echo "Nathaniel - Available Commands"
	@echo "=============================="
	@echo ""
	@echo "Running:"
	@echo "  make ios              Build and run iOS app in simulator"
	@echo "  make ios-device       Build and install iOS app on connected device"
	@echo "  make macos            Build and run macOS app"
	@echo "  make ios-fresh        Clean install iOS app (removes old app data)"
	@echo ""
	@echo "Building only:"
	@echo "  make ios-build        Build iOS app for simulator"
	@echo "  make ios-device-build Build iOS app for connected device"
	@echo "  make macos-build      Build macOS app"
	@echo ""
	@echo "Testing:"
	@echo "  make test             Run all smoke tests (iOS + macOS)"
	@echo "  make test-unit        Run macOS XCTest regression tests"
	@echo "  make test-tooling     Test build commands without running apps"
	@echo "  make test-ios         Run iOS simulator smoke tests"
	@echo "  make test-macos       Run macOS smoke tests"
	@echo "  make health           Check if GameCommandServer is running"
	@echo ""
	@echo "Code Quality:"
	@echo "  make lint             Run SwiftLint on the codebase"
	@echo "  make format           Run SwiftFormat on the codebase"
	@echo ""
	@echo "Cleaning:"
	@echo "  make clean            Clean all build products"
	@echo "  make clean-derived    Remove all Nathaniel DerivedData (fixes stale builds)"
	@echo "  make ios-clean        Clean iOS build products"
	@echo "  make macos-clean      Clean macOS build products"
	@echo "  make stop             Stop all running Nathaniel instances"
	@echo ""
	@echo "Utilities:"
	@echo "  make list-simulators  List available iOS simulators"
	@echo "  make list-devices     List connected iOS devices"
	@echo "  make shutdown-sims    Shutdown all running simulators"
	@echo "  make open-project     Open project in Xcode"
	@echo ""
	@echo "Options:"
	@echo "  SIMULATOR=<name>      iOS simulator name (default: $(SIMULATOR))"
	@echo "  CONFIG=<Debug|Release> Build configuration (default: $(CONFIG))"
	@echo "  DERIVED_DATA_PATH=<path> Build output directory (default: $(DERIVED_DATA_PATH))"
	@echo ""
	@echo "Examples:"
	@echo "  make ios SIMULATOR=\"iPhone 16\""
	@echo "  make macos CONFIG=Release"

# iOS targets
ios: ios-run

ios-build:
	@echo "Building $(IOS_SCHEME) ($(CONFIG))..."
	xcodebuild -project $(PROJECT) \
		-scheme "$(IOS_SCHEME)" \
		-configuration $(CONFIG) \
		-derivedDataPath "$(DERIVED_DATA_PATH)" \
		-destination 'platform=iOS Simulator,name=$(SIMULATOR)' \
		build

ios-run: ios-build
	@echo "Booting simulator..."
	@xcrun simctl boot "$(SIMULATOR)" 2>/dev/null || true
	@open -a Simulator
	@test -d "$(IOS_APP)"
	xcrun simctl install "$(SIMULATOR)" "$(IOS_APP)"
	xcrun simctl launch "$(SIMULATOR)" $(BUNDLE_ID)

# Explicit fresh install removes existing app data and build products.
ios-fresh: clean-derived
	@echo "Removing existing app data..."
	@xcrun simctl shutdown all 2>/dev/null || true
	@xcrun simctl boot "$(SIMULATOR)" 2>/dev/null || true
	@xcrun simctl uninstall "$(SIMULATOR)" $(BUNDLE_ID) 2>/dev/null || true
	$(MAKE) ios-run

# iOS device targets
ios-device: ios-device-build
	@echo "Installing on connected device..."
	@DEVICE_ID=$$(xcrun devicectl list devices 2>/dev/null | awk 'NR>2 && $$4 ~ /^[0-9A-F]/ {print $$4; exit}') && \
		if [ -z "$$DEVICE_ID" ]; then echo "Error: No connected device found. Run 'make list-devices' to check."; exit 1; fi && \
		APP_PATH="$(DEVICE_APP)" && \
		if [ ! -d "$$APP_PATH" ]; then echo "Error: Could not find built app. Run 'make ios-device-build' first."; exit 1; fi && \
		echo "Installing $$APP_PATH to device $$DEVICE_ID..." && \
		xcrun devicectl device install app --device "$$DEVICE_ID" "$$APP_PATH" && \
		echo "Launching app on device..." && \
		xcrun devicectl device process launch --device "$$DEVICE_ID" $(BUNDLE_ID) && \
		echo "Done! App is running on your device."

ios-device-build:
	@echo "Building $(IOS_SCHEME) for device ($(CONFIG))..."
	@DEVICE_ID=$$(xcrun devicectl list devices 2>/dev/null | awk 'NR>2 && $$4 ~ /^[0-9A-F]/ {print $$4; exit}') && \
		if [ -z "$$DEVICE_ID" ]; then \
			echo "Warning: No device connected. Building for generic iOS device..."; \
			xcodebuild -project $(PROJECT) \
				-scheme "$(IOS_SCHEME)" \
				-configuration $(CONFIG) \
				-derivedDataPath "$(DERIVED_DATA_PATH)" \
				-destination 'generic/platform=iOS' \
				build; \
		else \
			echo "Building for device $$DEVICE_ID..."; \
			xcodebuild -project $(PROJECT) \
				-scheme "$(IOS_SCHEME)" \
				-configuration $(CONFIG) \
				-derivedDataPath "$(DERIVED_DATA_PATH)" \
				-destination "platform=iOS,id=$$DEVICE_ID" \
				build; \
		fi

list-devices:
	@echo "Connected iOS Devices:"
	@echo "======================"
	@xcrun devicectl list devices 2>/dev/null || echo "No devices found or devicectl not available."
	@echo ""
	@echo "If your device is not listed, ensure:"
	@echo "  1. Device is connected via USB or WiFi"
	@echo "  2. Device is unlocked and trusted"
	@echo "  3. Developer Mode is enabled (Settings > Privacy & Security > Developer Mode)"

# macOS targets
macos: macos-run

macos-build:
	@echo "Building $(MACOS_SCHEME) ($(CONFIG))..."
	xcodebuild -project $(PROJECT) \
		-scheme "$(MACOS_SCHEME)" \
		-configuration $(CONFIG) \
		-derivedDataPath "$(DERIVED_DATA_PATH)" \
		build

macos-run: macos-build
	@test -d "$(MACOS_APP)"
	open "$(MACOS_APP)"

# Clean targets
clean: ios-clean macos-clean
	@echo "Clean complete."

ios-clean:
	@echo "Cleaning iOS build products..."
	xcodebuild -project $(PROJECT) \
		-scheme "$(IOS_SCHEME)" \
		-configuration $(CONFIG) \
		-derivedDataPath "$(DERIVED_DATA_PATH)" \
		clean

macos-clean:
	@echo "Cleaning macOS build products..."
	xcodebuild -project $(PROJECT) \
		-scheme "$(MACOS_SCHEME)" \
		-configuration $(CONFIG) \
		-derivedDataPath "$(DERIVED_DATA_PATH)" \
		clean

# Utility targets
list-simulators:
	@echo "Available iOS Simulators (iOS 26.1+ required):"
	@echo "================================================"
	@xcrun simctl list devices available

shutdown-sims:
	@echo "Shutting down all simulators..."
	@xcrun simctl shutdown all

clean-derived:
	@echo "Removing $(DERIVED_DATA_PATH)..."
	@test -n "$(DERIVED_DATA_PATH)" && test "$(DERIVED_DATA_PATH)" != /
	rm -rf "$(DERIVED_DATA_PATH)"
	@echo "Done. Next build will be from scratch."

open-project:
	@open $(PROJECT)

# Testing targets
test: test-macos test-ios
	@echo "All smoke tests complete."

test-ios:
	@echo "Running iOS simulator smoke tests..."
	@DERIVED_DATA_PATH="$(DERIVED_DATA_PATH)" ./scripts/smoke_ios_sim.sh

test-macos:
	@echo "Running macOS smoke tests..."
	@DERIVED_DATA_PATH="$(DERIVED_DATA_PATH)" ./scripts/test-macos.sh

test-unit:
	xcodebuild -project $(PROJECT) -scheme "$(MACOS_SCHEME)" \
		-configuration $(CONFIG) -destination 'platform=macOS' \
		-derivedDataPath "$(DERIVED_DATA_PATH)" test

test-tooling:
	python3 scripts/test_build_commands.py

health:
	@echo "Checking GameCommandServer health..."
	@curl -sf http://localhost:8765/health && echo "" || echo "GameCommandServer is not running. Start the game first with 'make ios' or 'make macos'."

# Code quality targets
lint:
	@echo "Running SwiftLint..."
	@command -v swiftlint >/dev/null || { echo "SwiftLint not installed. Run: brew install swiftlint"; exit 1; }
	swiftlint lint "Nathaniel Shared" "Nathaniel iOS" "Nathaniel macOS" NathanielTests --no-cache

format:
	@echo "Running SwiftFormat..."
	@command -v swiftformat >/dev/null || { echo "SwiftFormat not installed. Run: brew install swiftformat"; exit 1; }
	swiftformat "Nathaniel Shared" "Nathaniel iOS" "Nathaniel macOS" NathanielTests

# Stop all running instances
stop:
	@echo "Stopping all Nathaniel instances..."
	@pkill -f "Nathaniel.app" 2>/dev/null || true
	@xcrun simctl terminate booted $(BUNDLE_ID) 2>/dev/null || true
	@echo "Done."
