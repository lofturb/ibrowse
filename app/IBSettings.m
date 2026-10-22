#import "IBSettings.h"

NSString *const IBSettingsDidChangeNotification = @"IBSettingsDidChangeNotification";
NSString *const IBSettingsKeyBlockAds = @"IBBlockAds";
NSString *const IBSettingsKeyBlockTrackers = @"IBBlockTrackers";
NSString *const IBSettingsKeyCompatibility = @"IBCompatibility";
NSString *const IBSettingsKeyDesktopUA = @"IBDesktopUA";
NSString *const IBSettingsKeyPrivate = @"IBPrivate";
NSString *const IBSettingsKeyRelayEnabled = @"IBRelayEnabled";
NSString *const IBSettingsKeyRelayBaseURL = @"IBRelayBaseURL";
NSString *const IBSettingsKeySearchEngine = @"IBSearchEngine";
NSString *const IBSettingsKeyRestoreSession = @"IBRestoreSession";

@implementation IBSettings

+ (instancetype)sharedSettings {
    static IBSettings *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[IBSettings alloc] init];
    });
    return shared;
}

- (id)init {
    self = [super init];
    if (self) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSDictionary *registration = @{
            IBSettingsKeyBlockAds: @YES,
            IBSettingsKeyBlockTrackers: @YES,
            IBSettingsKeyCompatibility: @YES,
            IBSettingsKeyDesktopUA: @NO,
            IBSettingsKeyPrivate: @NO,
            IBSettingsKeyRelayEnabled: @NO,
            IBSettingsKeyRelayBaseURL: @"http://192.168.1.7:8099",
            IBSettingsKeySearchEngine: @"duckduckgo",
            IBSettingsKeyRestoreSession: @YES
        };
        [defaults registerDefaults:registration];
    }
    return self;
}

- (void)notifyChange {
    [[NSNotificationCenter defaultCenter] postNotificationName:IBSettingsDidChangeNotification
                                                        object:self];
}

- (BOOL)boolForKey:(NSString *)key {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

- (void)setBool:(BOOL)value forKey:(NSString *)key {
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self notifyChange];
}

- (BOOL)blockAds { return [self boolForKey:IBSettingsKeyBlockAds]; }
- (void)setBlockAds:(BOOL)value { [self setBool:value forKey:IBSettingsKeyBlockAds]; }

- (BOOL)blockTrackers { return [self boolForKey:IBSettingsKeyBlockTrackers]; }
- (void)setBlockTrackers:(BOOL)value { [self setBool:value forKey:IBSettingsKeyBlockTrackers]; }

- (BOOL)compatibilityMode { return [self boolForKey:IBSettingsKeyCompatibility]; }
- (void)setCompatibilityMode:(BOOL)value { [self setBool:value forKey:IBSettingsKeyCompatibility]; }

- (BOOL)desktopUserAgent { return [self boolForKey:IBSettingsKeyDesktopUA]; }
- (void)setDesktopUserAgent:(BOOL)value { [self setBool:value forKey:IBSettingsKeyDesktopUA]; }

- (BOOL)privateMode { return [self boolForKey:IBSettingsKeyPrivate]; }
- (void)setPrivateMode:(BOOL)value { [self setBool:value forKey:IBSettingsKeyPrivate]; }

- (BOOL)relayEnabled { return [self boolForKey:IBSettingsKeyRelayEnabled]; }
- (void)setRelayEnabled:(BOOL)value { [self setBool:value forKey:IBSettingsKeyRelayEnabled]; }

- (BOOL)restoreSession { return [self boolForKey:IBSettingsKeyRestoreSession]; }
- (void)setRestoreSession:(BOOL)value { [self setBool:value forKey:IBSettingsKeyRestoreSession]; }

- (NSString *)relayBaseURL {
    NSString *value = [[NSUserDefaults standardUserDefaults] stringForKey:IBSettingsKeyRelayBaseURL];
    if (!value || value.length == 0) { return @"http://192.168.1.7:8099"; }
    return value;
}

- (void)setRelayBaseURL:(NSString *)value {
    NSString *clean = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    while ([clean hasSuffix:@"/"]) {
        clean = [clean substringToIndex:clean.length - 1];
    }
    if (clean.length && ![clean hasPrefix:@"http://"] && ![clean hasPrefix:@"https://"]) {
        clean = [@"http://" stringByAppendingString:clean];
    }
    [[NSUserDefaults standardUserDefaults] setObject:clean forKey:IBSettingsKeyRelayBaseURL];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self notifyChange];
}

- (NSString *)searchEngine {
    NSString *value = [[NSUserDefaults standardUserDefaults] stringForKey:IBSettingsKeySearchEngine];
    return value ? value : @"duckduckgo";
}

- (void)setSearchEngine:(NSString *)value {
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:IBSettingsKeySearchEngine];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self notifyChange];
}

- (NSArray *)searchEngineChoices {
    return @[
        @{ @"key": @"duckduckgo", @"name": @"DuckDuckGo" },
        @{ @"key": @"google", @"name": @"Google" },
        @{ @"key": @"bing", @"name": @"Bing" },
        @{ @"key": @"startpage", @"name": @"Startpage" },
        @{ @"key": @"brave", @"name": @"Brave Search" },
        @{ @"key": @"wikipedia", @"name": @"Wikipedia (es)" }
    ];
}

- (NSString *)searchEngineName {
    NSString *key = [self searchEngine];
    NSArray *choices = [self searchEngineChoices];
    for (NSDictionary *item in choices) {
        if ([item[@"key"] isEqualToString:key]) {
            return item[@"name"];
        }
    }
    return @"DuckDuckGo";
}

- (BOOL)isRelayConfigured {
    NSString *value = [self relayBaseURL];
    return value.length > 7 && ([value hasPrefix:@"http://"] || [value hasPrefix:@"https://"]);
}

- (NSString *)userAgentString {
    if ([self desktopUserAgent]) {
        return @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
               @"AppleWebKit/605.1.15 (KHTML, like Gecko) "
               @"Version/17.0 Safari/605.1.15";
    }
    return @"Mozilla/5.0 (iPad; CPU OS 9_3_6 like Mac OS X) "
           @"AppleWebKit/601.1.46 (KHTML, like Gecko) "
           @"Version/9.0 Mobile/13G37 Safari/601.1";
}

@end
