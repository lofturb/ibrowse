#import <UIKit/UIKit.h>

@interface IBTheme : NSObject

+ (UIColor *)chrome;
+ (UIColor *)chromeDeep;
+ (UIColor *)chromeBorder;
+ (UIColor *)accent;
+ (UIColor *)text;
+ (UIColor *)secondaryText;
+ (UIColor *)tertiaryText;
+ (UIColor *)field;
+ (UIColor *)fieldBorder;
+ (UIColor *)selectedTab;
+ (UIColor *)danger;
+ (UIColor *)paper;

+ (UIFont *)fontOfSize:(CGFloat)size;
+ (UIFont *)mediumFontOfSize:(CGFloat)size;
+ (UIFont *)boldFontOfSize:(CGFloat)size;

+ (BOOL)isPad;
+ (CGFloat)hairline;
+ (NSString *)appVersion;

@end
