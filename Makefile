THEOS_PACKAGE_SCHEME := roothide
TARGET := iphone:clang:15.6:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := BarcodeSafari

BarcodeSafari_FILES := Tweak.xm
BarcodeSafari_CFLAGS := -fobjc-arc
BarcodeSafari_FRAMEWORKS := UIKit
BarcodeSafari_PRIVATE_FRAMEWORKS := ControlCenterUIKit
BarcodeSafari_INSTALL_TARGET_PROCESSES := ControlCenter

include $(THEOS_MAKE_PATH)/tweak.mk
