#import <UIKit/UIKit.h>

@interface IBTabChipView : UIView

@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign, getter=isSelected) BOOL selected;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, copy) void (^onSelect)(void);
@property (nonatomic, copy) void (^onClose)(void);

- (CGFloat)preferredWidth;

@end
