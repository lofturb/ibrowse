#import <Foundation/Foundation.h>

extern NSString *const IBDownloadsDidChangeNotification;

typedef NS_ENUM(NSInteger, IBDownloadState) {
    IBDownloadStateDownloading = 0,
    IBDownloadStateCompleted = 1,
    IBDownloadStateFailed = 2
};

@interface IBDownloadItem : NSObject
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, copy) NSString *filename;
@property (nonatomic, copy) NSString *localPath;
@property (nonatomic, assign) unsigned long long bytesWritten;
@property (nonatomic, assign) unsigned long long totalBytes;
@property (nonatomic, assign) IBDownloadState state;
@property (nonatomic, copy) NSString *errorMessage;
@property (nonatomic, assign) NSTimeInterval startedAt;
@property (nonatomic, assign) NSUInteger taskIdentifier;
@property (nonatomic, readonly) double fraction;
@property (nonatomic, readonly) BOOL isCompleted;
@end

@interface IBDownloadManager : NSObject

+ (instancetype)sharedManager;

@property (nonatomic, readonly) NSArray *items;

- (void)startDownloadFromURL:(NSURL *)url suggestedName:(NSString *)name;
- (void)cancelItem:(IBDownloadItem *)item;
- (void)removeItem:(IBDownloadItem *)item deleteFile:(BOOL)deleteFile;
- (void)clearFinished;

@end
