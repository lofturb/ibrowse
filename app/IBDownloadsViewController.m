#import "IBDownloadsViewController.h"
#import "IBDownloadManager.h"
#import "IBStore.h"
#import "IBTheme.h"

@interface IBDownloadsViewController () <UIDocumentInteractionControllerDelegate>

@property (nonatomic, strong) UIDocumentInteractionController *documentController;

@end

@implementation IBDownloadsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Descargas";
    self.tableView.rowHeight = 68.0;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.backgroundColor = [UIColor whiteColor];
    self.tableView.separatorColor = [IBTheme chromeBorder];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                             target:self
                             action:@selector(doneTapped)];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"Limpiar"
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(clearTapped)];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(downloadsDidChange:)
                                                 name:IBDownloadsDidChangeNotification
                                               object:nil];

    [self refresh];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refresh];
}

#pragma mark - Datos

- (void)downloadsDidChange:(NSNotification *)notification {
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(refresh)
                                               object:nil];
    [self performSelector:@selector(refresh)
               withObject:nil
               afterDelay:0.25];
}

- (void)refresh {
    [self updateEmptyState];
    [self.tableView reloadData];
    self.navigationItem.rightBarButtonItem.enabled =
        [[[IBDownloadManager sharedManager] items] count] > 0;
}

- (void)updateEmptyState {
    NSArray *items = [[IBDownloadManager sharedManager] items];
    if (items.count > 0) {
        self.tableView.backgroundView = nil;
        return;
    }

    UILabel *label = [[UILabel alloc] initWithFrame:self.tableView.bounds];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    label.font = [IBTheme fontOfSize:15.0];
    label.textColor = [IBTheme tertiaryText];
    label.text = @"No hay descargas.\n\nLos archivos se guardan en\n"
                 @"/var/mobile/Media/IBrowse/Downloads";
    self.tableView.backgroundView = label;
}

- (NSString *)detailForItem:(IBDownloadItem *)item {
    NSMutableArray *parts = [NSMutableArray array];

    if (item.state == IBDownloadStateDownloading) {
        if (item.totalBytes > 0) {
            [parts addObject:[NSString stringWithFormat:@"%.0f%%",
                              item.fraction * 100.0]];
            [parts addObject:[NSString stringWithFormat:@"%@ de %@",
                              [IBStore humanSize:item.bytesWritten],
                              [IBStore humanSize:item.totalBytes]]];
        } else if (item.bytesWritten > 0) {
            [parts addObject:[NSString stringWithFormat:@"%@ descargados",
                              [IBStore humanSize:item.bytesWritten]]];
        } else {
            [parts addObject:@"Conectando…"];
        }
    } else if (item.state == IBDownloadStateCompleted) {
        [parts addObject:@"Completado"];
        if (item.bytesWritten > 0) {
            [parts addObject:[IBStore humanSize:item.bytesWritten]];
        }
    } else {
        [parts addObject:item.errorMessage.length ? item.errorMessage : @"Error"];
    }

    if (item.startedAt > 0) {
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:item.startedAt];
        [parts addObject:[IBStore relativeDateString:date]];
    }
    return [parts componentsJoinedByString:@" · "];
}

#pragma mark - Acciones

- (void)doneTapped {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)clearTapped {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Limpiar descargas"
                         message:@"Se quitarán de la lista las descargas terminadas. "
                                  "Los archivos seguirán en la carpeta de descargas."
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Limpiar"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [[IBDownloadManager sharedManager] clearFinished];
        [self refresh];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)openItem:(IBDownloadItem *)item fromCell:(UITableViewCell *)cell {
    if (item.state == IBDownloadStateDownloading) {
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:item.filename
                             message:@"La descarga está en curso."
                      preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Seguir"
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar descarga"
                                                  style:UIAlertActionStyleDestructive
                                                handler:^(UIAlertAction *action) {
            [[IBDownloadManager sharedManager] cancelItem:item];
            [self refresh];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    UIAlertController *sheet = [UIAlertController
        alertControllerWithTitle:item.filename
                         message:[self detailForItem:item]
                  preferredStyle:UIAlertControllerStyleActionSheet];

    if (item.state == IBDownloadStateCompleted && item.localPath) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Abrir con…"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            [self presentOpenInForItem:item fromCell:cell];
        }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"Compartir…"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            [self shareItem:item fromCell:cell];
        }]];
    } else if (item.state == IBDownloadStateFailed) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Reintentar"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            [[IBDownloadManager sharedManager] startDownloadFromURL:item.url
                                                      suggestedName:item.filename];
            [self refresh];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"Eliminar de la lista"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
        [self confirmDeleteItem:item];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cerrar"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = cell;
        sheet.popoverPresentationController.sourceRect = cell.bounds;
        sheet.popoverPresentationController.permittedArrowDirections =
            UIPopoverArrowDirectionAny;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)confirmDeleteItem:(IBDownloadItem *)item {
    BOOL hasFile = item.state == IBDownloadStateCompleted && item.localPath;
    NSString *message = hasFile
        ? @"Se eliminará el archivo del iPad. Esta acción no se puede deshacer."
        : @"Se quitará la descarga de la lista.";

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Eliminar descarga"
                         message:message
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Eliminar"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
        [[IBDownloadManager sharedManager] removeItem:item deleteFile:hasFile];
        [self refresh];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)presentOpenInForItem:(IBDownloadItem *)item fromCell:(UITableViewCell *)cell {
    if (!item.localPath) { return; }

    NSURL *fileURL = [NSURL fileURLWithPath:item.localPath];
    UIDocumentInteractionController *controller =
        [UIDocumentInteractionController interactionControllerWithURL:fileURL];
    controller.delegate = self;
    self.documentController = controller;

    BOOL shown = [controller presentOpenInMenuFromRect:cell.bounds
                                                inView:cell
                                              animated:YES];
    if (!shown) {
        self.documentController = nil;
        [self shareItem:item fromCell:cell];
    }
}

- (void)shareItem:(IBDownloadItem *)item fromCell:(UITableViewCell *)cell {
    if (!item.localPath) { return; }

    NSURL *fileURL = [NSURL fileURLWithPath:item.localPath];
    UIActivityViewController *activity = [[UIActivityViewController alloc]
        initWithActivityItems:@[fileURL]
        applicationActivities:nil];
    if (activity.popoverPresentationController) {
        activity.popoverPresentationController.sourceView = cell;
        activity.popoverPresentationController.sourceRect = cell.bounds;
        activity.popoverPresentationController.permittedArrowDirections =
            UIPopoverArrowDirectionAny;
    }
    [self presentViewController:activity animated:YES completion:nil];
}

#pragma mark - UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)[[IBDownloadManager sharedManager] items].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"IBDownloadCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:identifier];
    }

    IBDownloadItem *item = [[IBDownloadManager sharedManager] items][(NSUInteger)indexPath.row];

    cell.textLabel.text = item.filename;
    cell.textLabel.font = [IBTheme mediumFontOfSize:15.0];
    cell.textLabel.textColor = [IBTheme text];
    cell.textLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;

    cell.detailTextLabel.text = [self detailForItem:item];
    cell.detailTextLabel.font = [IBTheme fontOfSize:11.5];
    cell.detailTextLabel.textColor = item.state == IBDownloadStateFailed
        ? [IBTheme danger]
        : [IBTheme tertiaryText];
    cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    IBDownloadItem *item = [[IBDownloadManager sharedManager] items][(NSUInteger)indexPath.row];
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    [self openItem:item fromCell:cell];
}

- (NSArray *)tableView:(UITableView *)tableView
    editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    IBDownloadItem *item = [[IBDownloadManager sharedManager] items][(NSUInteger)indexPath.row];

    UITableViewRowAction *remove = [UITableViewRowAction
        rowActionWithStyle:UITableViewRowActionStyleDestructive
                     title:@"Eliminar"
                   handler:^(UITableViewRowAction *action, NSIndexPath *path) {
        [self confirmDeleteItem:item];
    }];
    return @[remove];
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
     forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        IBDownloadItem *item = [[IBDownloadManager sharedManager] items][(NSUInteger)indexPath.row];
        [self confirmDeleteItem:item];
    }
}

@end
