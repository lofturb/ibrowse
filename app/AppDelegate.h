#import <UIKit/UIKit.h>

@class IBBrowserViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) IBBrowserViewController *browser;

- (void)openExternalURL:(NSURL *)url;

@end
