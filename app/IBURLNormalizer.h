#import <Foundation/Foundation.h>

@interface IBURLNormalizer : NSObject

+ (NSURL *)URLFromUserInput:(NSString *)text;
+ (NSURL *)URLFromUserInput:(NSString *)text searchEngine:(NSString *)engine;
+ (NSURL *)searchURLForQuery:(NSString *)query engine:(NSString *)engine;
+ (BOOL)looksLikeURL:(NSString *)text;
+ (BOOL)isStartURL:(NSURL *)url;
+ (BOOL)isHTTPURL:(NSURL *)url;

+ (NSString *)relayWrappedURLString:(NSURL *)url baseURL:(NSString *)baseURL;
+ (NSURL *)originalURLFromRelayURL:(NSURL *)url baseURL:(NSString *)baseURL;
+ (BOOL)isRelayURL:(NSURL *)url baseURL:(NSString *)baseURL;

+ (NSString *)encodedQuery:(NSString *)query;
+ (NSString *)displayHostForURL:(NSURL *)url;

@end
