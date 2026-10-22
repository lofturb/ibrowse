#import "IBBookmarkStore.h"
#import "IBStore.h"
#import "IBURLNormalizer.h"

NSString *const IBBookmarksDidChangeNotification = @"IBBookmarksDidChangeNotification";

@interface IBBookmarkStore ()
@property (nonatomic, strong) NSMutableArray *items;
@end

@implementation IBBookmarkStore

+ (instancetype)sharedStore {
    static IBBookmarkStore *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[IBBookmarkStore alloc] init];
    });
    return shared;
}

- (id)init {
    self = [super init];
    if (self) {
        id saved = [IBStore readPropertyListNamed:@"bookmarks.plist"];
        if ([saved isKindOfClass:[NSArray class]] && [saved count] > 0) {
            _items = [saved mutableCopy];
        } else {
            _items = [[self seedBookmarks] mutableCopy];
            [self save];
        }
    }
    return self;
}

- (NSArray *)seedBookmarks {
    NSArray *seed = @[
        @{ @"url": @"https://es.wikipedia.org/", @"title": @"Wikipedia",
           @"date": [NSDate date] },
        @{ @"url": @"https://html.duckduckgo.com/html/", @"title": @"DuckDuckGo",
           @"date": [NSDate date] },
        @{ @"url": @"https://archive.org/", @"title": @"Internet Archive",
           @"date": [NSDate date] },
        @{ @"url": @"https://news.ycombinator.com/", @"title": @"Hacker News",
           @"date": [NSDate date] }
    ];
    return seed;
}

- (NSArray *)entries {
    return [self.items copy];
}

- (void)save {
    [IBStore writePropertyList:self.items named:@"bookmarks.plist"];
    [[NSNotificationCenter defaultCenter] postNotificationName:IBBookmarksDidChangeNotification
                                                        object:self];
}

- (BOOL)isBookmarkedURL:(NSURL *)url {
    if (!url) { return NO; }
    NSString *absolute = url.absoluteString;
    for (NSDictionary *entry in self.items) {
        if ([entry[@"url"] isEqualToString:absolute]) { return YES; }
    }
    return NO;
}

- (void)addBookmarkURL:(NSURL *)url title:(NSString *)title {
    if (!url || [self isBookmarkedURL:url]) { return; }
    NSMutableDictionary *entry = [NSMutableDictionary dictionary];
    entry[@"url"] = url.absoluteString;
    entry[@"title"] = title.length ? title : [IBURLNormalizer displayHostForURL:url];
    entry[@"date"] = [NSDate date];
    [self.items insertObject:entry atIndex:0];
    [self save];
}

- (void)removeBookmarkURL:(NSURL *)url {
    if (!url) { return; }
    NSString *absolute = url.absoluteString;
    NSInteger found = -1;
    for (NSUInteger i = 0; i < self.items.count; i++) {
        if ([self.items[i][@"url"] isEqualToString:absolute]) {
            found = (NSInteger)i;
            break;
        }
    }
    if (found >= 0) {
        [self.items removeObjectAtIndex:(NSUInteger)found];
        [self save];
    }
}

- (BOOL)toggleBookmarkURL:(NSURL *)url title:(NSString *)title {
    if ([self isBookmarkedURL:url]) {
        [self removeBookmarkURL:url];
        return NO;
    }
    [self addBookmarkURL:url title:title];
    return YES;
}

- (void)removeEntryAtIndex:(NSUInteger)index {
    if (index >= self.items.count) { return; }
    [self.items removeObjectAtIndex:index];
    [self save];
}

@end
