#import <UIKit/UIKit.h>

@interface IBReaderViewController : UIViewController

@property (nonatomic, copy) void (^onOpenURL)(NSURL *url);

- (instancetype)initWithArticle:(NSDictionary *)article;

@end
