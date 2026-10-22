#import "IBContentBlocker.h"

@implementation IBContentBlocker

+ (NSString *)stringFromResource:(NSString *)name {
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"js"];
    if (!path) { return @""; }
    NSString *source = [NSString stringWithContentsOfFile:path
                                                encoding:NSUTF8StringEncoding
                                                   error:NULL];
    return source ? source : @"";
}

+ (NSString *)polyfillSource {
    return [self stringFromResource:@"ibrowse-polyfills"];
}

+ (NSString *)blockerSourceWithAds:(BOOL)ads trackers:(BOOL)trackers {
    NSString *body = [self stringFromResource:@"ibrowse-blocker"];
    if (body.length == 0) { return @""; }
    NSString *config = [NSString stringWithFormat:
        @"window.__IB_CONFIG = { ads: %@, trackers: %@ };\n",
        ads ? @"true" : @"false",
        trackers ? @"true" : @"false"];
    return [config stringByAppendingString:body];
}

+ (NSString *)bridgeSource {
    return [self stringFromResource:@"ibrowse-bridge"];
}

+ (NSString *)readerSource {
    return [self stringFromResource:@"ibrowse-reader"];
}

@end
