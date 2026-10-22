#import <UIKit/UIKit.h>

@interface IBErrorView : UIView

@property (nonatomic, copy) void (^onRetry)(void);
@property (nonatomic, copy) void (^onOpenSafari)(void);

- (void)showWithTitle:(NSString *)title message:(NSString *)message;
- (void)hide;

@end
