#import <Foundation/Foundation.h>

extern NSString *const IBSettingsDidChangeNotification;
extern NSString *const IBSettingsKeyBlockAds;
extern NSString *const IBSettingsKeyBlockTrackers;
extern NSString *const IBSettingsKeyCompatibility;
extern NSString *const IBSettingsKeyDesktopUA;
extern NSString *const IBSettingsKeyPrivate;
extern NSString *const IBSettingsKeyRelayEnabled;
extern NSString *const IBSettingsKeyRelayBaseURL;
extern NSString *const IBSettingsKeySearchEngine;
extern NSString *const IBSettingsKeyRestoreSession;

@interface IBSettings : NSObject

+ (instancetype)sharedSettings;

@property (nonatomic, assign) BOOL blockAds;
@property (nonatomic, assign) BOOL blockTrackers;
@property (nonatomic, assign) BOOL compatibilityMode;
@property (nonatomic, assign) BOOL desktopUserAgent;
@property (nonatomic, assign) BOOL privateMode;
@property (nonatomic, assign) BOOL relayEnabled;
@property (nonatomic, assign) BOOL restoreSession;

@property (nonatomic, copy) NSString *relayBaseURL;
@property (nonatomic, copy) NSString *searchEngine;

- (NSString *)searchEngineName;
- (NSArray *)searchEngineChoices;
- (NSString *)userAgentString;
- (BOOL)isRelayConfigured;

@end
