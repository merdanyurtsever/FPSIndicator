export TARGET = iphone:clang:15.6:15.0
export ARCHS = arm64

BUNDLE_NAME = FPSIndicator
BUNDLE_IDENTIFIER = com.fpsindicator

FPSIndicator_FILES = FPSIndicatorRootListController.m BDInfoListController.m
FPSIndicator_INSTALL_PATH = /var/jb/Library/PreferenceBundles
FPSIndicator_FRAMEWORKS = UIKit
FPSIndicator_PRIVATE_FRAMEWORKS = Preferences
FPSIndicator_CFLAGS = -fobjc-arc -Wno-deprecated -include Prefix.pch

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/var/jb/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/var/jb/Library/PreferenceLoader/Preferences/FPSIndicator.plist$(ECHO_END)
