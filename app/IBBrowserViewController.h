#import <UIKit/UIKit.h>

@interface IBBrowserViewController : UIViewController

- (void)openURL:(NSURL *)url;
- (void)openURLInNewTab:(NSURL *)url;
- (void)saveSession;

@end
