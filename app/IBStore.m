#import "IBStore.h"

@implementation IBStore

+ (NSString *)documentsDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                         NSUserDomainMask, YES);
    if (paths.count) { return [paths objectAtIndex:0]; }
    return NSTemporaryDirectory();
}

+ (NSString *)mediaDownloadsDirectory {
    static NSString *cached = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *media = @"/var/mobile/Media/IBrowse/Downloads";
        NSError *error = nil;
        if ([fm createDirectoryAtPath:media
          withIntermediateDirectories:YES
                           attributes:nil
                                error:&error]) {
            cached = media;
            return;
        }
        NSString *fallback = [[self documentsDirectory] stringByAppendingPathComponent:@"Downloads"];
        [fm createDirectoryAtPath:fallback
      withIntermediateDirectories:YES
                       attributes:nil
                            error:NULL];
        cached = fallback;
    });
    return cached;
}

+ (id)readPropertyListNamed:(NSString *)name {
    NSString *path = [[self documentsDirectory] stringByAppendingPathComponent:name];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) { return nil; }
    return [NSPropertyListSerialization propertyListWithData:data
                                                     options:NSPropertyListMutableContainers
                                                      format:NULL
                                                       error:NULL];
}

+ (BOOL)writePropertyList:(id)plist named:(NSString *)name {
    NSString *path = [[self documentsDirectory] stringByAppendingPathComponent:name];
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:plist
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                             options:0
                                                               error:NULL];
    return data ? [data writeToFile:path atomically:YES] : NO;
}

+ (NSString *)sanitizeFilename:(NSString *)name {
    if (!name || name.length == 0) { return @"descarga"; }
    NSString *clean = [name lastPathComponent];
    NSCharacterSet *bad = [NSCharacterSet characterSetWithCharactersInString:@"/\\:*?\"<>|\r\n\t"];
    clean = [[clean componentsSeparatedByCharactersInSet:bad] componentsJoinedByString:@"_"];
    clean = [clean stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (clean.length == 0 || [clean isEqualToString:@"."] || [clean isEqualToString:@".."]) {
        clean = @"descarga";
    }
    if (clean.length > 120) {
        NSString *extension = [clean pathExtension];
        NSString *base = [clean stringByDeletingPathExtension];
        if (extension.length && extension.length < 10) {
            base = [base substringToIndex:MIN((NSUInteger)108, base.length)];
            clean = [base stringByAppendingPathExtension:extension];
        } else {
            clean = [clean substringToIndex:120];
        }
    }
    return clean;
}

+ (NSString *)humanSize:(unsigned long long)bytes {
    if (bytes < 1024) {
        return [NSString stringWithFormat:@"%llu B", bytes];
    }
    double value = (double)bytes / 1024.0;
    NSArray *units = @[@"KB", @"MB", @"GB", @"TB"];
    NSUInteger index = 0;
    while (value >= 1024.0 && index < units.count - 1) {
        value /= 1024.0;
        index++;
    }
    return [NSString stringWithFormat:@"%.1f %@", value, [units objectAtIndex:index]];
}

+ (NSString *)relativeDateString:(NSDate *)date {
    if (!date) { return @""; }
    NSTimeInterval delta = -[date timeIntervalSinceNow];
    if (delta < 60) { return @"ahora"; }
    if (delta < 3600) {
        return [NSString stringWithFormat:@"hace %d min", (int)(delta / 60)];
    }
    if (delta < 86400) {
        return [NSString stringWithFormat:@"hace %d h", (int)(delta / 3600)];
    }
    if (delta < 86400 * 7) {
        return [NSString stringWithFormat:@"hace %d d", (int)(delta / 86400)];
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterShortStyle];
    [formatter setTimeStyle:NSDateFormatterNoStyle];
    return [formatter stringFromDate:date];
}

@end
