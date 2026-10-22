#import "IBDownloadManager.h"
#import "IBStore.h"
#import "IBSettings.h"
#import "IBURLNormalizer.h"

NSString *const IBDownloadsDidChangeNotification = @"IBDownloadsDidChangeNotification";

@implementation IBDownloadItem

- (double)fraction {
    if (self.totalBytes > 0) {
        return MIN(1.0, (double)self.bytesWritten / (double)self.totalBytes);
    }
    return 0.0;
}

- (BOOL)isCompleted {
    return self.state == IBDownloadStateCompleted;
}

@end

@interface IBDownloadManager () <NSURLSessionDownloadDelegate>
@property (nonatomic, strong) NSMutableArray *mutableItems;
@property (nonatomic, strong) NSMutableDictionary *tasks;
@property (nonatomic, strong) NSURLSession *session;
@end

@implementation IBDownloadManager

+ (instancetype)sharedManager {
    static IBDownloadManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[IBDownloadManager alloc] init];
    });
    return shared;
}

- (id)init {
    self = [super init];
    if (self) {
        _mutableItems = [NSMutableArray array];
        _tasks = [NSMutableDictionary dictionary];
        [self loadSavedItems];

        NSURLSessionConfiguration *configuration =
            [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.timeoutIntervalForRequest = 120.0;
        configuration.timeoutIntervalForResource = 3600.0;
        configuration.HTTPMaximumConnectionsPerHost = 2;
        configuration.HTTPShouldSetCookies = YES;
        _session = [NSURLSession sessionWithConfiguration:configuration
                                                 delegate:self
                                            delegateQueue:[NSOperationQueue mainQueue]];
    }
    return self;
}

- (NSArray *)items {
    return [self.mutableItems copy];
}

- (void)notify {
    [[NSNotificationCenter defaultCenter] postNotificationName:IBDownloadsDidChangeNotification
                                                        object:self];
}

- (void)loadSavedItems {
    id saved = [IBStore readPropertyListNamed:@"downloads.plist"];
    if (![saved isKindOfClass:[NSArray class]]) { return; }
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSDictionary *dict in saved) {
        if (![dict isKindOfClass:[NSDictionary class]]) { continue; }
        IBDownloadItem *item = [[IBDownloadItem alloc] init];
        item.url = [NSURL URLWithString:dict[@"url"] ?: @""];
        item.filename = dict[@"filename"] ?: @"descarga";
        item.localPath = dict[@"localPath"];
        item.bytesWritten = [dict[@"bytesWritten"] unsignedLongLongValue];
        item.totalBytes = [dict[@"totalBytes"] unsignedLongLongValue];
        item.state = (IBDownloadState)[dict[@"state"] integerValue];
        item.errorMessage = dict[@"error"];
        item.startedAt = [dict[@"startedAt"] doubleValue];
        if (item.state == IBDownloadStateCompleted) {
            if (!item.localPath || ![fm fileExistsAtPath:item.localPath]) { continue; }
        } else {
            item.state = IBDownloadStateFailed;
            item.errorMessage = item.errorMessage ?: @"Interrumpida";
        }
        [self.mutableItems addObject:item];
    }
}

- (void)save {
    NSMutableArray *saved = [NSMutableArray array];
    for (IBDownloadItem *item in self.mutableItems) {
        if (item.state == IBDownloadStateDownloading) { continue; }
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        dict[@"url"] = item.url.absoluteString ?: @"";
        dict[@"filename"] = item.filename ?: @"descarga";
        if (item.localPath) { dict[@"localPath"] = item.localPath; }
        dict[@"bytesWritten"] = @(item.bytesWritten);
        dict[@"totalBytes"] = @(item.totalBytes);
        dict[@"state"] = @(item.state);
        dict[@"startedAt"] = @(item.startedAt);
        if (item.errorMessage) { dict[@"error"] = item.errorMessage; }
        [saved addObject:dict];
    }
    [IBStore writePropertyList:saved named:@"downloads.plist"];
}

- (NSString *)availablePathForFilename:(NSString *)filename {
    NSString *directory = [IBStore mediaDownloadsDirectory];
    NSString *clean = [IBStore sanitizeFilename:filename];
    NSString *candidate = [directory stringByAppendingPathComponent:clean];
    NSFileManager *fm = [NSFileManager defaultManager];

    if (![fm fileExistsAtPath:candidate]) { return candidate; }

    NSString *base = [clean stringByDeletingPathExtension];
    NSString *extension = [clean pathExtension];
    for (int i = 1; i < 1000; i++) {
        NSString *name = extension.length
            ? [NSString stringWithFormat:@"%@-%d.%@", base, i, extension]
            : [NSString stringWithFormat:@"%@-%d", base, i];
        candidate = [directory stringByAppendingPathComponent:name];
        if (![fm fileExistsAtPath:candidate]) { return candidate; }
    }
    return candidate;
}

- (void)startDownloadFromURL:(NSURL *)url suggestedName:(NSString *)name {
    if (!url || ![IBURLNormalizer isHTTPURL:url]) { return; }

    IBSettings *settings = [IBSettings sharedSettings];
    NSURL *logical = url;
    if ([IBURLNormalizer isRelayURL:url baseURL:settings.relayBaseURL]) {
        NSURL *original = [IBURLNormalizer originalURLFromRelayURL:url
                                                           baseURL:settings.relayBaseURL];
        if (original) { logical = original; }
    }

    NSString *filename = name.length ? name : [logical lastPathComponent];
    if ([filename isEqualToString:@"asset"] ||
        [filename isEqualToString:@"browse"] ||
        [filename isEqualToString:@"download"]) {
        filename = [logical lastPathComponent];
    }
    if (!filename.length) { filename = @"descarga"; }
    if ([filename rangeOfString:@"."].location == NSNotFound &&
        logical.pathExtension.length) {
        filename = [filename stringByAppendingPathExtension:logical.pathExtension];
    }

    IBDownloadItem *item = [[IBDownloadItem alloc] init];
    item.url = url;
    item.filename = [IBStore sanitizeFilename:filename];
    item.localPath = [self availablePathForFilename:item.filename];
    item.filename = [item.localPath lastPathComponent];
    item.state = IBDownloadStateDownloading;
    item.startedAt = [[NSDate date] timeIntervalSince1970];

    [self.mutableItems insertObject:item atIndex:0];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:120.0];
    [request setValue:[[IBSettings sharedSettings] userAgentString]
   forHTTPHeaderField:@"User-Agent"];
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:url];
    if (cookies.count) {
        NSDictionary *headers = [NSHTTPCookie requestHeaderFieldsWithCookies:cookies];
        NSString *cookieHeader = headers[@"Cookie"];
        if (cookieHeader.length) {
            [request setValue:cookieHeader forHTTPHeaderField:@"Cookie"];
        }
    }

    NSURLSessionDownloadTask *task = [self.session downloadTaskWithRequest:request];
    item.taskIdentifier = task.taskIdentifier;
    [self.tasks setObject:item forKey:@(task.taskIdentifier)];
    [task resume];

    [self notify];
}

- (void)cancelItem:(IBDownloadItem *)item {
    if (!item) { return; }
    NSURLSessionDownloadTask *task = [self.tasks objectForKey:@(item.taskIdentifier)];
    if (task) {
        [task cancel];
        [self.tasks removeObjectForKey:@(item.taskIdentifier)];
    }
    item.state = IBDownloadStateFailed;
    item.errorMessage = @"Cancelada";
    [self notify];
    [self save];
}

- (void)removeItem:(IBDownloadItem *)item deleteFile:(BOOL)deleteFile {
    if (!item) { return; }
    if (item.state == IBDownloadStateDownloading) {
        [self cancelItem:item];
    }
    if (deleteFile && item.localPath) {
        [[NSFileManager defaultManager] removeItemAtPath:item.localPath error:NULL];
    }
    [self.mutableItems removeObjectIdenticalTo:item];
    [self notify];
    [self save];
}

- (void)clearFinished {
    NSMutableArray *keep = [NSMutableArray array];
    for (IBDownloadItem *item in self.mutableItems) {
        if (item.state == IBDownloadStateDownloading) {
            [keep addObject:item];
        }
    }
    [self.mutableItems setArray:keep];
    [self notify];
    [self save];
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    IBDownloadItem *item = [self.tasks objectForKey:@(downloadTask.taskIdentifier)];
    if (!item) { return; }
    item.bytesWritten = (unsigned long long)totalBytesWritten;
    if (totalBytesExpectedToWrite > 0) {
        item.totalBytes = (unsigned long long)totalBytesExpectedToWrite;
    }
    [self notify];
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {
    IBDownloadItem *item = [self.tasks objectForKey:@(downloadTask.taskIdentifier)];
    if (!item) { return; }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *destination = item.localPath;
    if (!destination) {
        destination = [self availablePathForFilename:item.filename];
        item.localPath = destination;
    }
    if ([fm fileExistsAtPath:destination]) {
        [fm removeItemAtPath:destination error:NULL];
    }

    NSError *error = nil;
    if (![fm moveItemAtURL:location toURL:[NSURL fileURLWithPath:destination] error:&error]) {
        item.state = IBDownloadStateFailed;
        item.errorMessage = error.localizedDescription ?: @"No se pudo guardar el archivo";
    } else {
        item.state = IBDownloadStateCompleted;
        item.errorMessage = nil;
        if (item.bytesWritten == 0) {
            NSDictionary *attributes = [fm attributesOfItemAtPath:destination error:NULL];
            item.bytesWritten = [attributes[NSFileSize] unsignedLongLongValue];
            item.totalBytes = item.bytesWritten;
        }
    }
    [self notify];
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    IBDownloadItem *item = [self.tasks objectForKey:@(task.taskIdentifier)];
    if (!item) { return; }

    if (error && item.state != IBDownloadStateCompleted) {
        item.state = IBDownloadStateFailed;
        if (error.code == NSURLErrorCancelled) {
            item.errorMessage = @"Cancelada";
        } else {
            item.errorMessage = error.localizedDescription ?: @"Error de descarga";
        }
    }
    [self.tasks removeObjectForKey:@(task.taskIdentifier)];
    [self notify];
    [self save];
}

@end
