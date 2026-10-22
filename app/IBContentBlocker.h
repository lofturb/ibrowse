#import <Foundation/Foundation.h>

@interface IBContentBlocker : NSObject

+ (NSString *)polyfillSource;
+ (NSString *)blockerSourceWithAds:(BOOL)ads trackers:(BOOL)trackers;
+ (NSString *)bridgeSource;
+ (NSString *)readerSource;

@end
