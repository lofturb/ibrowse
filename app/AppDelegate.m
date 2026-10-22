#import "AppDelegate.h"
#import "IBBrowserViewController.h"
#import "IBTheme.h"
#import "IBDownloadManager.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [IBTheme chrome];

    self.browser = [[IBBrowserViewController alloc] init];
    self.window.rootViewController = self.browser;
    [self.window makeKeyAndVisible];

    /* Arranca los gestores que dependen de notificaciones. */
    [IBDownloadManager sharedManager];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(saveSessionFromNotification:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(saveSessionFromNotification:)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
    return YES;
}

- (void)saveSessionFromNotification:(NSNotification *)notification {
    [self saveSession];
}

- (void)saveSession {
    [self.browser saveSession];
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
            options:(NSDictionary *)options {
    if ([[url.scheme lowercaseString] isEqualToString:@"ibrowse"]) {
        NSString *value = nil;

        NSURLComponents *components = [NSURLComponents componentsWithURL:url
                                                  resolvingAgainstBaseURL:NO];
        for (NSURLQueryItem *item in components.queryItems) {
            if ([item.name isEqualToString:@"url"] && item.value.length) {
                value = item.value;
                break;
            }
        }
        if (!value.length) {
            value = [url.absoluteString stringByReplacingOccurrencesOfString:@"ibrowse://"
                                                                  withString:@""];
            if ([value hasPrefix:@"open?url="]) {
                value = [value substringFromIndex:9];
            }
            value = [value stringByRemovingPercentEncoding];
        }

        if (value.length) {
            NSURL *target = [NSURL URLWithString:value];
            if (target) {
                [self.browser openURL:target];
                return YES;
            }
        }
        return YES;
    }
    return NO;
}

- (void)openExternalURL:(NSURL *)url {
    if (!url) { return; }
    UIApplication *application = [UIApplication sharedApplication];
    if ([application canOpenURL:url]) {
        [application openURL:url];
    }
}

@end
