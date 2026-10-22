#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, IBListMode) {
    IBListModeBookmarks = 0,
    IBListModeHistory = 1
};

@interface IBListViewController : UITableViewController

@property (nonatomic, copy) void (^onSelectEntry)(NSDictionary *entry, BOOL newTab);

- (instancetype)initWithMode:(IBListMode)mode;

@end
