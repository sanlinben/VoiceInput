TC := $(HOME)/Library/Developer/Toolchains/Swift-6.0.3-RELEASE.xctoolchain
SDKROOT := /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
SWIFT := $(TC)/usr/bin/swift
BUILD_DIR := $(CURDIR)/.build
SCRIPTS_DIR := $(BUILD_DIR)/checkouts/speech-swift/scripts

# DEVELOPER_DIR bypasses Xcode license check when CLT is installed
DEV_DIR := /Library/Developer/CommandLineTools

.PHONY: build run clean

build:
	DEVELOPER_DIR=$(DEV_DIR) SDKROOT=$(SDKROOT) "$(SWIFT)" build -c release -Xswiftc "-gnone"
	BUILD_DIR=$(BUILD_DIR) "$(SCRIPTS_DIR)/build_mlx_metallib.sh" release

debug:
	DEVELOPER_DIR=$(DEV_DIR) SDKROOT=$(SDKROOT) "$(SWIFT)" build -c debug -Xswiftc "-gnone"
	BUILD_DIR=$(BUILD_DIR) "$(SCRIPTS_DIR)/build_mlx_metallib.sh" debug

run: build
	DEVELOPER_DIR=$(DEV_DIR) "$(BUILD_DIR)/release/VoiceInput"

clean:
	rm -rf "$(BUILD_DIR)"
