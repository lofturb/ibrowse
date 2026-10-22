#import "IBListViewController.h"
#import "IBBookmarkStore.h"
#import "IBHistoryStore.h"
#import "IBTheme.h"
#import "IBStore.h"

@interface IBListViewController () <UISearchBarDelegate>

@property (nonatomic, assign) IBListMode mode;
@property (nonatomic, strong) NSArray *entries;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, copy) NSString *filter;

@end

@implementation IBListViewController

- (instancetype)initWithMode:(IBListMode)mode {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _mode = mode;
        _entries = [NSArray array];
        _filter = @"";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tableView.rowHeight = 62.0;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.backgroundColor = [UIColor whiteColor];
    self.tableView.separatorColor = [IBTheme chromeBorder];

    UISearchBar *search = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    search.placeholder = @"Filtrar";
    search.delegate = self;
    search.barTintColor = [IBTheme chrome];
    search.searchBarStyle = UISearchBarStyleMinimal;
    search.autocapitalizationType = UITextAutocapitalizationTypeNone;
    search.autocorrectionType = UITextAutocorrectionTypeNo;
    self.searchBar = search;
    self.tableView.tableHeaderView = search;

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                             target:self
                             action:@selector(doneTapped)];

    if (self.mode == IBListModeHistory) {
        self.title = @"Historial";
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
            initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                 target:self
                                 action:@selector(clearTapped)];
    } else {
        self.title = @"Marcadores";
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(storeDidChange:)
                                                 name:IBBookmarksDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(storeDidChange:)
                                                 name:IBHistoryDidChangeNotification
                                               object:nil];

    [self reloadEntries];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.searchBar.superview == self.tableView) {
        CGFloat width = self.tableView.bounds.size.width;
        if (self.searchBar.frame.size.width != width) {
            self.searchBar.frame = CGRectMake(0, 0, width, 44.0);
            self.tableView.tableHeaderView = self.searchBar;
        }
    }
}

#pragma mark - Datos

- (NSArray *)sourceEntries {
    if (self.mode == IBListModeBookmarks) {
        return [[IBBookmarkStore sharedStore] entries];
    }
    return [[IBHistoryStore sharedStore] entries];
}

- (void)reloadEntries {
    NSArray *source = [self sourceEntries];
    NSString *needle = [self.filter lowercaseString];

    if (needle.length == 0) {
        self.entries = source;
    } else {
        NSMutableArray *filtered = [NSMutableArray array];
        for (NSDictionary *entry in source) {
            NSString *title = [entry[@"title"] lowercaseString];
            NSString *url = [entry[@"url"] lowercaseString];
            if (([title isKindOfClass:[NSString class]] &&
                 [title rangeOfString:needle].location != NSNotFound) ||
                ([url isKindOfClass:[NSString class]] &&
                 [url rangeOfString:needle].location != NSNotFound)) {
                [filtered addObject:entry];
            }
        }
        self.entries = filtered;
    }

    [self updateEmptyState];
    [self.tableView reloadData];
}

- (void)updateEmptyState {
    if (self.entries.count > 0) {
        self.tableView.backgroundView = nil;
        return;
    }

    UILabel *label = [[UILabel alloc] initWithFrame:self.tableView.bounds];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    label.font = [IBTheme fontOfSize:15.0];
    label.textColor = [IBTheme tertiaryText];
    label.text = self.mode == IBListModeBookmarks
        ? @"No hay marcadores.\nUsa la estrella de la barra de direcciones."
        : @"No hay historial todavía.";
    self.tableView.backgroundView = label;
}

- (void)storeDidChange:(NSNotification *)notification {
    [self reloadEntries];
}

#pragma mark - Acciones

- (void)doneTapped {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)clearTapped {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Borrar historial"
                         message:@"Se eliminarán todas las páginas visitadas. Esta acción no se puede deshacer."
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Borrar"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
        [[IBHistoryStore sharedStore] clear];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)finishWithEntry:(NSDictionary *)entry newTab:(BOOL)newTab {
    if (self.onSelectEntry) {
        self.onSelectEntry(entry, newTab);
    }
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)deleteEntry:(NSDictionary *)entry {
    if (self.mode == IBListModeBookmarks) {
        NSURL *url = [NSURL URLWithString:entry[@"url"]];
        [[IBBookmarkStore sharedStore] removeBookmarkURL:url];
    } else {
        NSUInteger index = [[[IBHistoryStore sharedStore] entries]
                            indexOfObjectIdenticalTo:entry];
        if (index != NSNotFound) {
            [[IBHistoryStore sharedStore] removeEntryAtIndex:index];
        }
    }
}

#pragma mark - UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.entries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"IBListCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:identifier];
    }

    NSDictionary *entry = self.entries[(NSUInteger)indexPath.row];
    NSString *title = entry[@"title"];
    NSString *url = entry[@"url"];

    cell.textLabel.text = title.length ? title : url;
    cell.textLabel.font = [IBTheme mediumFontOfSize:15.0];
    cell.textLabel.textColor = [IBTheme text];
    cell.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    cell.detailTextLabel.text = url;
    cell.detailTextLabel.font = [IBTheme fontOfSize:11.5];
    cell.detailTextLabel.textColor = [IBTheme tertiaryText];
    cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;

    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *entry = self.entries[(NSUInteger)indexPath.row];
    [self finishWithEntry:entry newTab:NO];
}

- (NSArray *)tableView:(UITableView *)tableView
    editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *entry = self.entries[(NSUInteger)indexPath.row];

    UITableViewRowAction *open = [UITableViewRowAction
        rowActionWithStyle:UITableViewRowActionStyleNormal
                     title:@"Nueva\npestaña"
                   handler:^(UITableViewRowAction *action, NSIndexPath *path) {
        [self finishWithEntry:entry newTab:YES];
    }];
    open.backgroundColor = [IBTheme accent];

    UITableViewRowAction *remove = [UITableViewRowAction
        rowActionWithStyle:UITableViewRowActionStyleDestructive
                     title:@"Eliminar"
                   handler:^(UITableViewRowAction *action, NSIndexPath *path) {
        [self deleteEntry:entry];
    }];

    return @[remove, open];
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
     forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSDictionary *entry = self.entries[(NSUInteger)indexPath.row];
        [self deleteEntry:entry];
    }
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.filter = searchText ? searchText : @"";
    [self reloadEntries];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = @"";
    self.filter = @"";
    [searchBar resignFirstResponder];
    [self reloadEntries];
}

@end
