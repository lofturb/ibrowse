#import "IBTheme.h"

@implementation IBTheme

+ (UIColor *)color:(CGFloat)r g:(CGFloat)g b:(CGFloat)b {
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1.0];
}

+ (UIColor *)chrome { return [self color:247 g:248 b:251]; }
+ (UIColor *)chromeDeep { return [self color:237 g:240 b:246]; }
+ (UIColor *)chromeBorder { return [self color:214 g:219 b:229]; }
+ (UIColor *)accent { return [self color:27 g:104 b:242]; }
+ (UIColor *)text { return [self color:20 g:24 b:33]; }
+ (UIColor *)secondaryText { return [self color:95 g:103 b:119]; }
+ (UIColor *)tertiaryText { return [self color:143 g:151 b:166]; }
+ (UIColor *)field { return [UIColor whiteColor]; }
+ (UIColor *)fieldBorder { return [self color:207 g:213 b:224]; }
+ (UIColor *)selectedTab { return [UIColor whiteColor]; }
+ (UIColor *)danger { return [self color:196 g:43 b:56]; }
+ (UIColor *)paper { return [self color:251 g:248 b:241]; }

+ (UIFont *)fontOfSize:(CGFloat)size {
    return [UIFont systemFontOfSize:size];
}

+ (UIFont *)mediumFontOfSize:(CGFloat)size {
    if ([UIFont respondsToSelector:@selector(systemFontOfSize:weight:)]) {
        return [UIFont systemFontOfSize:size weight:UIFontWeightMedium];
    }
    return [UIFont boldSystemFontOfSize:size];
}

+ (UIFont *)boldFontOfSize:(CGFloat)size {
    if ([UIFont respondsToSelector:@selector(systemFontOfSize:weight:)]) {
        return [UIFont systemFontOfSize:size weight:UIFontWeightSemibold];
    }
    return [UIFont boldSystemFontOfSize:size];
}

+ (BOOL)isPad {
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
}

+ (CGFloat)hairline {
    CGFloat scale = [[UIScreen mainScreen] scale];
    return scale > 1.0 ? (1.0 / scale) : 1.0;
}

+ (NSString *)appVersion {
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    return version ? version : @"1.0.0";
}

@end
