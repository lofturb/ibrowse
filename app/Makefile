# ---------------------------------------------------------------------------
#  IBrowse — navegador para iPad mini 1 / iOS 9.3.6 (armv7)
#
#  Compilar:
#    make clean && make package FINALPACKAGE=1 PACKAGE_FORMAT=ipa
#
#  El CI lo hace solo con Theos + toolchain LLVM + SDK 9.3.
# ---------------------------------------------------------------------------

TARGET = iphone:clang:9.3:9.0
ARCHS = armv7
PACKAGE_FORMAT = ipa

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = IBrowse

IBrowse_FILES = \
	main.m \
	AppDelegate.m \
	IBTheme.m \
	IBStore.m \
	IBSettings.m \
	IBURLNormalizer.m \
	IBHistoryStore.m \
	IBBookmarkStore.m \
	IBWebTab.m \
	IBContentBlocker.m \
	IBDownloadManager.m \
	IBTabChipView.m \
	IBErrorView.m \
	IBBrowserViewController.m \
	IBListViewController.m \
	IBDownloadsViewController.m \
	IBReaderViewController.m \
	IBSettingsViewController.m \
	IBAboutViewController.m

IBrowse_FRAMEWORKS = UIKit Foundation WebKit CoreGraphics QuartzCore
IBrowse_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-parameter
IBrowse_RESOURCE_DIRS = Resources
IBrowse_LDFLAGS = -Wl,-dead_strip

# Llavero + acceso a /var/mobile/Media (descargas visibles por AFC/Filza).
IBrowse_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
