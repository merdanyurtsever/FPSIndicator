TARGET = iphone:clang:15.6:15.0
ARCHS = arm64
SYSROOT = $(THEOS)/sdks/iPhoneOS15.6.sdk

INSTALL_TARGET_PROCESSES = SpringBoard backboardd

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FPSIndicator

# Files updated for the PUBG Mobile enhanced version
FPSIndicator_FILES = Tweak.xm \
	Sources/FPSCounter.m \
	Sources/FPSDisplay.m \
	Sources/FPSPreferences.m \
	Sources/FPSGameSupport.m \
	Sources/FPSAlternativeOverlay.m \
	Sources/FPSPUBGSupport.m \
	Sources/FPSPUBGUIIntegration.m \
	Sources/FPSLogViewer.m \
	Sources/FPSThermalMonitor.m \
	Sources/FPSGraphView.m

FPSIndicator_CFLAGS = -fobjc-arc -include Prefix.pch
FPSIndicator_FRAMEWORKS = UIKit QuartzCore
FPSIndicator_LIBRARIES = substrate
FPSIndicator_INSTALL_PATH = /var/jb/Library/MobileSubstrate/DynamicLibraries

SUBPROJECTS += fpsindicatorpref

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

# Test configuration
TEST_NAME = FPSIndicatorTests
TESTS_DIR = tests
$(TEST_NAME)_FILES = $(TESTS_DIR)/FPSIndicatorTests.m
$(TEST_NAME)_FRAMEWORKS = XCTest OCMock UIKit
$(TEST_NAME)_CFLAGS = -fobjc-arc

# Test targets
test::
	@$(MAKE) -f $(THEOS_MAKE_PATH)/test.mk
	@./$(THEOS_OBJ_DIR)/$(TEST_NAME)

# Proper rootless staging
internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/var/jb/Library/{MobileSubstrate/DynamicLibraries,PreferenceBundles/FPSIndicator.bundle,PreferenceLoader/Preferences}$(ECHO_END)
	$(ECHO_NOTHING)cp FPSIndicator.plist $(THEOS_STAGING_DIR)$(FPSIndicator_INSTALL_PATH)/$(ECHO_END)

# Modern respring approach
after-install::
	install.exec "uicache -p /Applications/Preferences.app && killall -9 SpringBoard"
