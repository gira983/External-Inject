ARCHS := arm64 arm64e
TARGET := iphone:clang:16.5:14.0
DEBUG = 0
FINALPACKAGE = 1
FOR_RELEASE = 1
INSTALL_TARGET_PROCESSES := FFExternal

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME := FFExternal

$(APPLICATION_NAME)_USE_MODULES := 0

$(APPLICATION_NAME)_FILES += $(wildcard sources/*.mm sources/*.m)
$(APPLICATION_NAME)_FILES += $(wildcard sources/KIF/*.mm sources/KIF/*.m)
$(APPLICATION_NAME)_FILES += $(wildcard esp/drawing_view/*.mm)
$(APPLICATION_NAME)_FILES += $(wildcard esp/helpers/*.mm)

sources/KIF/UITouch-KIFAdditions.m_CFLAGS := $(filter-out -mllvm -enable-fco,$(FFExternal_CFLAGS))

$(APPLICATION_NAME)_CFLAGS += -fobjc-arc \
	-Wno-deprecated-declarations \
	-Wno-unused-variable \
	-Wno-unused-value \
	-Wno-module-import-in-extern-c \
	-Wno-unused-but-set-variable \
	-Wno-unused-function

$(APPLICATION_NAME)_OBJCCFLAGS += -fobjc-arc

$(APPLICATION_NAME)_CXXFLAGS  += -std=c++17
$(APPLICATION_NAME)_OBJCXXFLAGS += -std=c++17

$(APPLICATION_NAME)_CFLAGS += -Iheaders
$(APPLICATION_NAME)_CFLAGS += -Isources
$(APPLICATION_NAME)_CFLAGS += -Isources/KIF
$(APPLICATION_NAME)_CFLAGS += -Iesp/helpers
$(APPLICATION_NAME)_CFLAGS += -Iesp/drawing_view
$(APPLICATION_NAME)_CFLAGS += -DNOTIFY_DESTROY_HUD="\"com.gira983.ffexternal.hud.destroy\""
$(APPLICATION_NAME)_CFLAGS += -DPID_PATH="@\"/var/mobile/Library/Caches/com.gira983.ffexternal.pid\""

$(APPLICATION_NAME)_FRAMEWORKS += CoreGraphics CoreServices QuartzCore IOKit UIKit AVFoundation AudioToolbox CoreMedia
$(APPLICATION_NAME)_PRIVATE_FRAMEWORKS += BackBoardServices GraphicsServices SpringBoardServices

$(APPLICATION_NAME)_CODESIGN_FLAGS += -Slayout/entitlements.plist
$(APPLICATION_NAME)_RESOURCE_DIRS = ./layout/Resources

include $(THEOS_MAKE_PATH)/application.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

after-all::
	@rm -rf packages Payload
	@mkdir -p Payload
	@cp -R .theos/obj/$(APPLICATION_NAME).app Payload
	@zip -rq $(APPLICATION_NAME).tipa Payload
	@rm -rf Payload
	@mkdir -p packages
	@mv $(APPLICATION_NAME).tipa packages
