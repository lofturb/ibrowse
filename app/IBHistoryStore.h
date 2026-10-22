#import <Foundation/Foundation.h>

extern NSString *const IBHistoryDidChangeNotification;

@interface IBHistoryStore : NSObject

+ (instancetype)sharedStore;

@property (nonatomic, readonly) NSArray *entries;

- (void)addEntryWithURL:(NSURL *)url title:(NSString *)title;
- (void)removeEntryAtIndex:(NSUInteger)index;
- (void)clear;

@end
