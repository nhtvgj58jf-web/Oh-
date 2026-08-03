TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = Telegram

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ProfileCustomTweak
ProfileCustomTweak_FILES = Tweak.xm
ProfileCustomTweak_CFLAGS = -fobjc-arc
ProfileCustomTweak_FRAMEWORKS = UIKit AVFoundation

include $(THEOS_MAKE_PATH)/tweak.mk

after-install:: 
    install.exec "killall -9 Telegram"
