#import <Foundation/Foundation.h>

extern NSString *const IBBookmarksDidChangeNotification;

@interface IBBookmarkStore : NSObject

+ (instancetype)sharedStore;

@property (nonatomic, readonly) NSArray *entries;

- (BOOL)isBookmarkedURL:(NSURL *)url;
- (BOOL)toggleBookmarkURL:(NSURL *)url title:(NSString *)title;
- (void)addBookmarkURL:(NSURL *)url title:(NSString *)title;
- (void)removeBookmarkURL:(NSURL *)url;
- (void)removeEntryAtIndex:(NSUInteger)index;

@end
