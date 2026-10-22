#import "IBSettingsViewController.h"
#import "IBSettings.h"
#import "IBTheme.h"
#import "IBHistoryStore.h"
#import "IBStore.h"
#import <WebKit/WebKit.h>

@interface IBSettingsViewController () <UITextFieldDelegate>

@property (nonatomic, strong) UITextField *relayField;

@end

@implementation IBSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Ajustes";
    self.tableView.backgroundColor = [IBTheme chromeDeep];
    self.tableView.separatorColor = [IBTheme chromeBorder];
    self.tableView.rowHeight = 46.0;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                             target:self
                             action:@selector(doneTapped)];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self commitRelayField];
}

#pragma mark - Tabla

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 5;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 4;
        case 1: return 3;
        case 2: return 3;
        case 3: return 3;
        default: return 1;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"Navegación";
        case 1: return @"Compatibilidad";
        case 2: return @"Modo Relay";
        case 3: return @"Datos";
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"El modo privado no guarda historial ni sesión, y usa un almacén de datos temporal. "
                "Al activarlo se recargan las pestañas abiertas.";
    }
    if (section == 1) {
        return @"Los polyfills añaden APIs modernas (Promise, fetch parcial, IntersectionObserver…) "
                "al WebKit de iOS 9. No hacen compatible cualquier web al 100 %. "
                "Recarga la página después de cambiar estas opciones.";
    }
    if (section == 2) {
        return @"El relay es un servidor Node.js en tu red local que adapta el JavaScript moderno "
                "y reescribe HTML/CSS. Puede ver las páginas y cookies que pasan por él: úsalo solo "
                "en una red de confianza. Ejemplo: http://192.168.1.7:8099";
    }
    if (section == 3) {
        return @"Los archivos descargados se guardan en /var/mobile/Media/IBrowse/Downloads "
                "(visibles desde Filza o AFC).";
    }
    return @"IBrowse compila para armv7 / iOS 9.3.6 y usa el WebKit del sistema.";
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    switch (section) {
        case 0: return 52.0;
        case 1: return 62.0;
        case 2: return 96.0;
        case 3: return 44.0;
        default: return 36.0;
    }
}

- (void)tableView:(UITableView *)tableView willDisplayFooterView:(UIView *)view
       forSection:(NSInteger)section {
    UITableViewHeaderFooterView *footer = (UITableViewHeaderFooterView *)view;
    footer.textLabel.font = [IBTheme fontOfSize:11.5];
    footer.textLabel.textColor = [IBTheme secondaryText];
}

- (UISwitch *)switchForSection:(NSInteger)section row:(NSInteger)row {
    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.onTintColor = [IBTheme accent];
    toggle.tag = section * 100 + row;
    [toggle addTarget:self
               action:@selector(switchChanged:)
     forControlEvents:UIControlEventValueChanged];
    return toggle;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"IBSettingsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:identifier];
    }
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.textLabel.font = [IBTheme fontOfSize:15.0];
    cell.textLabel.textColor = [IBTheme text];
    cell.detailTextLabel.font = [IBTheme fontOfSize:13.0];
    cell.detailTextLabel.textColor = [IBTheme tertiaryText];
    cell.textLabel.text = @"";
    cell.detailTextLabel.text = @"";

    IBSettings *settings = [IBSettings sharedSettings];

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Motor de búsqueda";
            cell.detailTextLabel.text = [settings searchEngineName];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Pedir versión de escritorio";
            UISwitch *toggle = [self switchForSection:0 row:1];
            toggle.on = settings.desktopUserAgent;
            cell.accessoryView = toggle;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"Restaurar sesión al abrir";
            UISwitch *toggle = [self switchForSection:0 row:2];
            toggle.on = settings.restoreSession;
            cell.accessoryView = toggle;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            cell.textLabel.text = @"Modo privado";
            UISwitch *toggle = [self switchForSection:0 row:3];
            toggle.on = settings.privateMode;
            cell.accessoryView = toggle;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Bloquear anuncios";
            UISwitch *toggle = [self switchForSection:1 row:0];
            toggle.on = settings.blockAds;
            cell.accessoryView = toggle;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Bloquear rastreadores";
            UISwitch *toggle = [self switchForSection:1 row:1];
            toggle.on = settings.blockTrackers;
            cell.accessoryView = toggle;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            cell.textLabel.text = @"Compatibilidad (polyfills)";
            UISwitch *toggle = [self switchForSection:1 row:2];
            toggle.on = settings.compatibilityMode;
            cell.accessoryView = toggle;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Activar Modo Relay";
            UISwitch *toggle = [self switchForSection:2 row:0];
            toggle.on = settings.relayEnabled;
            cell.accessoryView = toggle;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Dirección del relay";

            UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 230, 30)];
            field.text = settings.relayBaseURL;
            field.placeholder = @"http://192.168.1.7:8099";
            field.font = [IBTheme fontOfSize:13.0];
            field.textColor = [IBTheme text];
            field.textAlignment = NSTextAlignmentRight;
            field.keyboardType = UIKeyboardTypeURL;
            field.autocapitalizationType = UITextAutocapitalizationTypeNone;
            field.autocorrectionType = UITextAutocorrectionTypeNo;
            field.spellCheckingType = UITextSpellCheckingTypeNo;
            field.returnKeyType = UIReturnKeyDone;
            field.delegate = self;
            self.relayField = field;
            cell.accessoryView = field;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            cell.textLabel.text = @"Probar conexión";
            cell.textLabel.textColor = [IBTheme accent];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    } else if (indexPath.section == 3) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Borrar historial";
            cell.textLabel.textColor = [IBTheme text];
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Borrar caché y cookies";
            cell.textLabel.textColor = [IBTheme text];
        } else {
            cell.textLabel.text = @"Restaurar ajustes";
            cell.textLabel.textColor = [IBTheme danger];
        }
    } else {
        cell.textLabel.text = [NSString stringWithFormat:@"IBrowse %@",
                               [IBTheme appVersion]];
        cell.textLabel.textColor = [IBTheme secondaryText];
        cell.textLabel.font = [IBTheme fontOfSize:13.0];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0 && indexPath.row == 0) {
        [self chooseSearchEngineFromCell:[tableView cellForRowAtIndexPath:indexPath]];
        return;
    }

    if (indexPath.section == 2 && indexPath.row == 1) {
        [self.relayField becomeFirstResponder];
        return;
    }

    if (indexPath.section == 2 && indexPath.row == 2) {
        [self testRelay];
        return;
    }

    if (indexPath.section == 3) {
        if (indexPath.row == 0) { [self confirmClearHistory]; }
        else if (indexPath.row == 1) { [self confirmClearWebsiteData]; }
        else { [self confirmRestoreDefaults]; }
    }
}

#pragma mark - Acciones

- (void)switchChanged:(UISwitch *)toggle {
    NSInteger section = toggle.tag / 100;
    NSInteger row = toggle.tag % 100;
    IBSettings *settings = [IBSettings sharedSettings];

    if (section == 0) {
        if (row == 1) { settings.desktopUserAgent = toggle.isOn; }
        else if (row == 2) { settings.restoreSession = toggle.isOn; }
        else if (row == 3) { settings.privateMode = toggle.isOn; }
    } else if (section == 1) {
        if (row == 0) { settings.blockAds = toggle.isOn; }
        else if (row == 1) { settings.blockTrackers = toggle.isOn; }
        else { settings.compatibilityMode = toggle.isOn; }
    } else if (section == 2 && row == 0) {
        settings.relayEnabled = toggle.isOn;
    }
}

- (void)chooseSearchEngineFromCell:(UITableViewCell *)cell {
    IBSettings *settings = [IBSettings sharedSettings];
    UIAlertController *sheet = [UIAlertController
        alertControllerWithTitle:@"Motor de búsqueda"
                         message:nil
                  preferredStyle:UIAlertControllerStyleActionSheet];

    __weak typeof(self) weakSelf = self;
    for (NSDictionary *choice in [settings searchEngineChoices]) {
        NSString *key = choice[@"key"];
        NSString *name = choice[@"name"];
        BOOL selected = [key isEqualToString:[settings searchEngine]];
        NSString *title = selected
            ? [NSString stringWithFormat:@"\u2713 %@", name]
            : name;

        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            settings.searchEngine = key;
            [weakSelf.tableView reloadData];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancelar"
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

- (void)commitRelayField {
    if (!self.relayField) { return; }
    NSString *value = [self.relayField.text stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    IBSettings *settings = [IBSettings sharedSettings];
    if (![value isEqualToString:settings.relayBaseURL]) {
        settings.relayBaseURL = value;
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    [self commitRelayField];
}

- (void)testRelay {
    [self.view endEditing:YES];

    IBSettings *settings = [IBSettings sharedSettings];
    NSString *base = settings.relayBaseURL;
    if (![settings isRelayConfigured]) {
        [self showMessage:@"Configura primero la dirección del relay."];
        return;
    }

    NSString *health = [base stringByAppendingString:@"/health"];
    NSURL *url = [NSURL URLWithString:health];
    if (!url) {
        [self showMessage:@"La dirección del relay no es válida."];
        return;
    }

    [self showMessage:@"Conectando con el relay…"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:5.0];
    [request setValue:@"IBrowse" forHTTPHeaderField:@"User-Agent"];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [self showMessage:[NSString stringWithFormat:
                    @"No se pudo conectar.\n\n%@\n\nComprueba que el servidor esté "
                     "encendido, que el iPad y el PC estén en la misma red y que "
                     "la IP sea correcta.",
                    error.localizedDescription ?: @"Error de red"]];
                return;
            }
            NSInteger status = 200;
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                status = [(NSHTTPURLResponse *)response statusCode];
            }
            if (status >= 200 && status < 400) {
                [self showMessage:[NSString stringWithFormat:
                    @"Relay conectado (HTTP %ld).", (long)status]];
            } else {
                [self showMessage:[NSString stringWithFormat:
                    @"El relay respondió con HTTP %ld. Revisa la consola del servidor.",
                    (long)status]];
            }
        });
    }];
    [task resume];
}

- (void)showMessage:(NSString *)message {
    if (self.presentedViewController) {
        [self dismissViewControllerAnimated:NO completion:^{
            [self showMessage:message];
        }];
        return;
    }
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Modo Relay"
                         message:message
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Aceptar"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)confirmClearHistory {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Borrar historial"
                         message:@"Se eliminarán todas las páginas visitadas."
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Borrar"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
        [[IBHistoryStore sharedStore] clear];
        [self showMessage:@"Historial borrado."];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)confirmClearWebsiteData {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Borrar caché y cookies"
                         message:@"Se cerrarán las sesiones de las webs y se vaciará la caché. "
                                  "Las pestañas abiertas pueden necesitar recargarse."
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Borrar"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
        [self clearWebsiteData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)clearWebsiteData {
    [[NSURLCache sharedURLCache] removeAllCachedResponses];

    NSHTTPCookieStorage *cookies = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [cookies cookies]) {
        [cookies deleteCookie:cookie];
    }

    NSSet *types = [WKWebsiteDataStore allWebsiteDataTypes];
    WKWebsiteDataStore *store = [WKWebsiteDataStore defaultDataStore];
    [store fetchDataRecordsOfTypes:types
                 completionHandler:^(NSArray *records) {
        [store removeDataOfTypes:types
                   modifiedSince:[NSDate dateWithTimeIntervalSince1970:0]
               completionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showMessage:@"Caché y cookies borradas."];
            });
        }];
    }];
}

- (void)confirmRestoreDefaults {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Restaurar ajustes"
                         message:@"Se restablecerán todas las preferencias de IBrowse. "
                                  "Los marcadores, el historial y las descargas no se tocan."
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Restaurar"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
        NSString *bundle = [[NSBundle mainBundle] bundleIdentifier];
        if (bundle) {
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundle];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        [[NSNotificationCenter defaultCenter]
            postNotificationName:IBSettingsDidChangeNotification
                          object:[IBSettings sharedSettings]];
        [self.tableView reloadData];
        [self showMessage:@"Ajustes restaurados."];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)doneTapped {
    [self.view endEditing:YES];
    [self commitRelayField];
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

@end
