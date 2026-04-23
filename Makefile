TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = AutoJBHelper

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = AutoJBHelper

AutoJBHelper_FILES = AutoJBHelper/main.m AutoJBHelper/AppDelegate.m
AutoJBHelper_FRAMEWORKS = UIKit Foundation BackgroundTasks AVFoundation
AutoJBHelper_CFLAGS = -fobjc-arc
AutoJBHelper_LDFLAGS = -ldl
AutoJBHelper_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
