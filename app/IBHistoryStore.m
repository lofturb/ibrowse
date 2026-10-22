#import "IBHistoryStore.h"
#import "IBStore.h"
#import "IBSettings.h"
#import "IBURLNormalizer.h"

NSString *const IBHistoryDidChangeNotification = @"IBHistoryDidChangeNotification";

@interface IBHistoryStore ()
@property (nonatomic, strong) NSMutableArray *items;
@end

@implementation IBHistoryStore

+ (instancetype)sharedStore {
    static IBHistoryStore *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[IBHistoryStore alloc] init];
    });
    return shared;
}

- (id)init {
    self = [super init];
    if (self) {
        id saved = [IBStore readPropertyListNamed:@"history.plist"];
        if ([saved isKindOfClass:[NSArray class]]) {
            _items = [saved mutableCopy];
        } else {
            _items = [NSMutableArray array];
        }
    }
    return self;
}

- (NSArray *)entries {
    return [self.items copy];
}

- (void)save {
    [IBStore writePropertyList:self.items named:@"history.plist"];
    [[NSNotificationCenter defaultCenter] postNotificationName:IBHistoryDidChangeNotification
                                                        object:self];
}

- (void)addEntryWithURL:(NSURL *)url title:(NSString *)title {
    if (!url) { return; }
    if ([[IBSettings sharedSettings] privateMode]) { return; }
    if (![IBURLNormalizer isHTTPURL:url]) { return; }

    NSString *absolute = url.absoluteString;
    if (absolute.length == 0) { return; }

    NSDictionary *first = self.items.count ? self.items[0] : nil;
    if (first && [first[@"url"] isEqualToString:absolute]) {
        NSDate *date = first[@"date"];
        if (date && -[date timeIntervalSinceNow] < 60) {
            if (title.length && ![title isEqualToString:first[@"title"]]) {
                NSMutableDictionary *updated = [first mutableCopy];
                updated[@"title"] = title;
                [self.items replaceObjectAtIndex:0 withObject:updated];
                [self save];
            }
            return;
        }
    }

    NSMutableDictionary *entry = [NSMutableDictionary dictionary];
    entry[@"url"] = absolute;
    entry[@"title"] = title.length ? title : [IBURLNormalizer displayHostForURL:url];
    entry[@"date"] = [NSDate date];

    [self.items insertObject:entry atIndex:0];
    if (self.items.count > 1000) {
        [self.items removeObjectsInRange:NSMakeRange(1000, self.items.count - 1000)];
    }
    [self save];
}

- (void)removeEntryAtIndex:(NSUInteger)index {
    if (index >= self.items.count) { return; }
    [self.items removeObjectAtIndex:index];
    [self save];
}

- (void)clear {
    [self.items removeAllObjects];
    [self save];
}

@end
