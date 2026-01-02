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

.PHONY: help ios macos ios-build macos-build ios-run macos-run clean ios-clean macos-clean list-simulators shutdown-sims ios-fresh clean-derived test test-ios test-macos lint format health stop ios-device ios-device-build list-devices

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
		-destination 'platform=iOS Simulator,name=$(SIMULATOR)' \
		build

ios-run:
	@echo "Building and running $(IOS_SCHEME) on $(SIMULATOR)..."
	@echo "Booting simulator..."
	@xcrun simctl boot "$(SIMULATOR)" 2>/dev/null || true
	@open -a Simulator
	@echo "Building app..."
	@xcodebuild -project $(PROJECT) \
		-scheme "$(IOS_SCHEME)" \
		-configuration $(CONFIG) \
		-destination 'platform=iOS Simulator,name=$(SIMULATOR)' \
		build 2>&1 | tail -20
	@echo ""
	@echo "Uninstalling old version (if any)..."
	@xcrun simctl uninstall "$(SIMULATOR)" $(BUNDLE_ID) 2>/dev/null || true
	@echo "Installing fresh build..."
	@APP_PATH=$$(find ~/Library/Developer/Xcode/DerivedData -name "Nathaniel.app" -path "*$(CONFIG)-iphonesimulator*" -type d 2>/dev/null | head -1) && \
		if [ -z "$$APP_PATH" ]; then echo "Error: Could not find built app"; exit 1; fi && \
		echo "Installing from: $$APP_PATH" && \
		xcrun simctl install "$(SIMULATOR)" "$$APP_PATH" && \
		echo "Launching app..." && \
		xcrun simctl launch "$(SIMULATOR)" $(BUNDLE_ID)

# Fresh iOS install (cleans DerivedData, uninstalls app, rebuilds from scratch)
ios-fresh:
	@echo "Fresh install of $(IOS_SCHEME) on $(SIMULATOR)..."
	@echo "Cleaning DerivedData..."
	@rm -rf ~/Library/Developer/Xcode/DerivedData/Nathaniel-*
	@echo "Shutting down simulators..."
	@xcrun simctl shutdown all 2>/dev/null || true
	@echo "Booting $(SIMULATOR)..."
	@xcrun simctl boot "$(SIMULATOR)" 2>/dev/null || true
	@open -a Simulator
	@sleep 2
	@echo "Uninstalling existing app..."
	@xcrun simctl uninstall "$(SIMULATOR)" $(BUNDLE_ID) 2>/dev/null || true
	@echo "Building app (clean build)..."
	@xcodebuild -project $(PROJECT) \
		-scheme "$(IOS_SCHEME)" \
		-configuration $(CONFIG) \
		-destination 'platform=iOS Simulator,name=$(SIMULATOR)' \
		build 2>&1 | tail -20
	@echo ""
	@echo "Installing fresh build..."
	@APP_PATH=$$(find ~/Library/Developer/Xcode/DerivedData -name "Nathaniel.app" -path "*$(CONFIG)-iphonesimulator*" -type d 2>/dev/null | head -1) && \
		if [ -z "$$APP_PATH" ]; then echo "Error: Could not find built app"; exit 1; fi && \
		echo "Installing from: $$APP_PATH" && \
		xcrun simctl install "$(SIMULATOR)" "$$APP_PATH" && \
		echo "Launching app..." && \
		xcrun simctl launch "$(SIMULATOR)" $(BUNDLE_ID)

# iOS device targets
ios-device: ios-device-build
	@echo "Installing on connected device..."
	@DEVICE_ID=$$(xcrun devicectl list devices 2>/dev/null | awk 'NR>2 && $$4 ~ /^[0-9A-F]/ {print $$4; exit}') && \
		if [ -z "$$DEVICE_ID" ]; then echo "Error: No connected device found. Run 'make list-devices' to check."; exit 1; fi && \
		APP_PATH=$$(find ~/Library/Developer/Xcode/DerivedData -name "Nathaniel.app" -path "*$(CONFIG)-iphoneos*" -type d 2>/dev/null | head -1) && \
		if [ -z "$$APP_PATH" ]; then echo "Error: Could not find built app. Run 'make ios-device-build' first."; exit 1; fi && \
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
				-destination 'generic/platform=iOS' \
				build; \
		else \
			echo "Building for device $$DEVICE_ID..."; \
			xcodebuild -project $(PROJECT) \
				-scheme "$(IOS_SCHEME)" \
				-configuration $(CONFIG) \
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
		build

macos-run:
	@echo "Building and running $(MACOS_SCHEME) ($(CONFIG))..."
	xcodebuild -project $(PROJECT) \
		-scheme "$(MACOS_SCHEME)" \
		-configuration $(CONFIG) \
		build
	@echo "Launching app..."
	@APP_PATH=$$(find ~/Library/Developer/Xcode/DerivedData -name "Nathaniel.app" -path "*$(CONFIG)*" -not -path "*iphonesimulator*" -type d 2>/dev/null | head -1) && \
		open "$$APP_PATH"

# Clean targets
clean: ios-clean macos-clean
	@echo "Clean complete."

ios-clean:
	@echo "Cleaning iOS build products..."
	xcodebuild -project $(PROJECT) \
		-scheme "$(IOS_SCHEME)" \
		-configuration $(CONFIG) \
		clean

macos-clean:
	@echo "Cleaning macOS build products..."
	xcodebuild -project $(PROJECT) \
		-scheme "$(MACOS_SCHEME)" \
		-configuration $(CONFIG) \
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
	@echo "Removing all Nathaniel DerivedData directories..."
	@rm -rf ~/Library/Developer/Xcode/DerivedData/Nathaniel-*
	@echo "Done. Next build will be from scratch."

open-project:
	@open $(PROJECT)

# Testing targets
test: test-macos test-ios
	@echo "All smoke tests complete."

test-ios:
	@echo "Running iOS simulator smoke tests..."
	@./scripts/smoke_ios_sim.sh

test-macos:
	@echo "Running macOS smoke tests..."
	@./scripts/test-macos.sh

health:
	@echo "Checking GameCommandServer health..."
	@curl -sf http://localhost:8765/health && echo "" || echo "GameCommandServer is not running. Start the game first with 'make ios' or 'make macos'."

# Code quality targets
lint:
	@echo "Running SwiftLint..."
	@swiftlint lint --path "Nathaniel Shared" --path "Nathaniel iOS" --path "Nathaniel macOS" 2>/dev/null || echo "SwiftLint not installed. Run: brew install swiftlint"

format:
	@echo "Running SwiftFormat..."
	@swiftformat "Nathaniel Shared" "Nathaniel iOS" "Nathaniel macOS" 2>/dev/null || echo "SwiftFormat not installed. Run: brew install swiftformat"

# Stop all running instances
stop:
	@echo "Stopping all Nathaniel instances..."
	@pkill -f "Nathaniel.app" 2>/dev/null || true
	@xcrun simctl terminate booted $(BUNDLE_ID) 2>/dev/null || true
	@echo "Done."
