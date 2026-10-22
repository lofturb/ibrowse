#import <Foundation/Foundation.h>

@interface IBStore : NSObject

+ (NSString *)documentsDirectory;
+ (NSString *)mediaDownloadsDirectory;

+ (id)readPropertyListNamed:(NSString *)name;
+ (BOOL)writePropertyList:(id)plist named:(NSString *)name;

+ (NSString *)sanitizeFilename:(NSString *)name;
+ (NSString *)humanSize:(unsigned long long)bytes;
+ (NSString *)relativeDateString:(NSDate *)date;

@end
