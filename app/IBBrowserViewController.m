#import "IBBrowserViewController.h"

#import "IBWebTab.h"
#import "IBTabChipView.h"
#import "IBTheme.h"
#import "IBSettings.h"
#import "IBURLNormalizer.h"
#import "IBHistoryStore.h"
#import "IBBookmarkStore.h"
#import "IBDownloadManager.h"
#import "IBErrorView.h"
#import "IBListViewController.h"
#import "IBDownloadsViewController.h"
#import "IBReaderViewController.h"
#import "IBSettingsViewController.h"
#import "IBAboutViewController.h"
#import "AppDelegate.h"

static const CGFloat IBKTabBarHeight = 38.0;
static const CGFloat IBKAddressRowHeight = 48.0;
static const CGFloat IBKTabChipHeight = 30.0;
static const CGFloat IBKButtonWidth = 42.0;

@interface IBBrowserViewController () <IBWebTabDelegate, UITextFieldDelegate>

@property (nonatomic, strong) NSMutableArray *tabs;
@property (nonatomic, assign) NSInteger currentIndex;

@property (nonatomic, strong) UIView *chrome;
@property (nonatomic, strong) UIView *tabBar;
@property (nonatomic, strong) UIScrollView *tabScrollView;
@property (nonatomic, strong) UIButton *addTabButton;
@property (nonatomic, strong) UIView *addressRow;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UIButton *forwardButton;
@property (nonatomic, strong) UIButton *reloadButton;
@property (nonatomic, strong) UIButton *bookmarkButton;
@property (nonatomic, strong) UIButton *menuButton;
@property (nonatomic, strong) UIView *addressContainer;
@property (nonatomic, strong) UILabel *schemeLabel;
@property (nonatomic, strong) UITextField *addressField;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) IBErrorView *errorView;
@property (nonatomic, strong) UILabel *toastLabel;
@property (nonatomic, strong) NSMutableArray *chips;

@property (nonatomic, assign) BOOL editingAddress;
@property (nonatomic, assign) BOOL lastPrivateMode;

@end

@implementation IBBrowserViewController

#pragma mark - Ciclo de vida

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _tabs = [NSMutableArray array];
        _chips = [NSMutableArray array];
        _currentIndex = -1;
        _lastPrivateMode = [[IBSettings sharedSettings] privateMode];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(settingsDidChange:)
                                                     name:IBSettingsDidChangeNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [IBTheme chrome];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                 UIViewAutoresizingFlexibleHeight;

    [self buildChrome];

    if ([[IBSettings sharedSettings] restoreSession]) {
        [self restoreSession];
    }
    if (self.tabs.count == 0) {
        [self createTabWithURL:nil makeCurrent:YES];
    } else {
        [self attachCurrentTab];
    }

    [self reloadTabChips];
    [self updateAddressBar];
    [self updateNavigationButtons];
    [self updatePrivateLook];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.tabs.count == 0) {
        [self createTabWithURL:nil makeCurrent:YES];
    }
    [self attachCurrentTab];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat top = self.topLayoutGuide.length;
    if (top <= 0.0) { top = 20.0; }

    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;

    CGFloat tabHeight = IBKTabBarHeight;
    CGFloat addressHeight = IBKAddressRowHeight;
    CGFloat chromeHeight = top + tabHeight + addressHeight;

    self.chrome.frame = CGRectMake(0, 0, width, chromeHeight);
    self.tabBar.frame = CGRectMake(0, top, width, tabHeight);
    [self layoutChromeLines];

    CGFloat addWidth = 42.0;
    self.tabScrollView.frame = CGRectMake(6, 4, width - addWidth - 8, tabHeight - 8);
    self.addTabButton.frame = CGRectMake(width - addWidth - 2, top + 1, addWidth, tabHeight - 2);

    self.addressRow.frame = CGRectMake(0, top + tabHeight, width, addressHeight);

    CGFloat x = 4.0;
    CGFloat buttonHeight = addressHeight;
    self.backButton.frame = CGRectMake(x, 0, IBKButtonWidth, buttonHeight);
    x += IBKButtonWidth;
    self.forwardButton.frame = CGRectMake(x, 0, IBKButtonWidth, buttonHeight);
    x += IBKButtonWidth;
    self.reloadButton.frame = CGRectMake(x, 0, IBKButtonWidth, buttonHeight);
    x += IBKButtonWidth;

    CGFloat rightWidth = IBKButtonWidth * 2.0;
    CGFloat fieldWidth = MAX(80.0, width - x - rightWidth - 8.0);
    self.addressContainer.frame = CGRectMake(x, 7, fieldWidth, addressHeight - 14);
    self.menuButton.frame = CGRectMake(width - IBKButtonWidth - 4, 0,
                                       IBKButtonWidth, buttonHeight);
    self.bookmarkButton.frame = CGRectMake(width - rightWidth - 4, 0,
                                           IBKButtonWidth, buttonHeight);

    self.schemeLabel.frame = CGRectMake(4, 0, 44, addressHeight - 14);
    self.addressField.frame = CGRectMake(50, 0, fieldWidth - 58, addressHeight - 14);

    self.progressView.frame = CGRectMake(0, addressHeight - 2, width, 2);

    self.contentView.frame = CGRectMake(0, chromeHeight, width,
                                        MAX(0, height - chromeHeight));
    self.errorView.frame = self.contentView.bounds;

    [self layoutCurrentWebView];
    [self layoutChips];
    [self layoutToast];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];

    IBWebTab *current = [self currentTab];
    for (NSUInteger i = 0; i < self.tabs.count; i++) {
        IBWebTab *tab = self.tabs[i];
        if (tab != current) { [tab unload]; }
    }
}

#pragma mark - Construcción de la interfaz

- (UIButton *)chromeButtonWithTitle:(NSString *)title size:(CGFloat)size {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[IBTheme accent] forState:UIControlStateNormal];
    [button setTitleColor:[IBTheme tertiaryText] forState:UIControlStateDisabled];
    button.titleLabel.font = [IBTheme fontOfSize:size];
    button.showsTouchWhenHighlighted = NO;
    button.adjustsImageWhenDisabled = NO;
    return button;
}

- (void)buildChrome {
    self.chrome = [[UIView alloc] initWithFrame:CGRectZero];
    self.chrome.backgroundColor = [IBTheme chrome];
    self.chrome.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.chrome];

    self.tabBar = [[UIView alloc] initWithFrame:CGRectZero];
    self.tabBar.backgroundColor = [IBTheme chrome];
    [self.chrome addSubview:self.tabBar];

    UIView *tabLine = [[UIView alloc] initWithFrame:CGRectZero];
    tabLine.tag = 901;
    tabLine.backgroundColor = [IBTheme chromeBorder];
    tabLine.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.tabBar addSubview:tabLine];

    self.tabScrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.tabScrollView.showsHorizontalScrollIndicator = NO;
    self.tabScrollView.showsVerticalScrollIndicator = NO;
    self.tabScrollView.alwaysBounceHorizontal = YES;
    self.tabScrollView.backgroundColor = [UIColor clearColor];
    [self.tabBar addSubview:self.tabScrollView];

    self.addTabButton = [self chromeButtonWithTitle:@"+"
                                              size:24.0];
    self.addTabButton.accessibilityLabel = @"Nueva pestaña";
    [self.addTabButton addTarget:self
                          action:@selector(newTabTapped)
                forControlEvents:UIControlEventTouchUpInside];
    [self.tabBar addSubview:self.addTabButton];

    self.addressRow = [[UIView alloc] initWithFrame:CGRectZero];
    self.addressRow.backgroundColor = [IBTheme chrome];
    self.addressRow.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.chrome addSubview:self.addressRow];

    self.backButton = [self chromeButtonWithTitle:@"\u2039" size:30.0];
    self.backButton.accessibilityLabel = @"Atrás";
    [self.backButton addTarget:self
                        action:@selector(goBack)
              forControlEvents:UIControlEventTouchUpInside];
    [self.addressRow addSubview:self.backButton];

    self.forwardButton = [self chromeButtonWithTitle:@"\u203A" size:30.0];
    self.forwardButton.accessibilityLabel = @"Adelante";
    [self.forwardButton addTarget:self
                           action:@selector(goForward)
                 forControlEvents:UIControlEventTouchUpInside];
    [self.addressRow addSubview:self.forwardButton];

    self.reloadButton = [self chromeButtonWithTitle:@"\u21BB" size:21.0];
    self.reloadButton.accessibilityLabel = @"Recargar";
    [self.reloadButton addTarget:self
                          action:@selector(reloadTapped)
                forControlEvents:UIControlEventTouchUpInside];
    [self.addressRow addSubview:self.reloadButton];

    self.addressContainer = [[UIView alloc] initWithFrame:CGRectZero];
    self.addressContainer.backgroundColor = [IBTheme field];
    self.addressContainer.layer.cornerRadius = 10.0;
    self.addressContainer.layer.borderWidth = 1.0;
    self.addressContainer.layer.borderColor = [IBTheme fieldBorder].CGColor;
    self.addressContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.addressRow addSubview:self.addressContainer];

    self.schemeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.schemeLabel.font = [IBTheme boldFontOfSize:9.5];
    self.schemeLabel.textColor = [IBTheme tertiaryText];
    self.schemeLabel.textAlignment = NSTextAlignmentCenter;
    self.schemeLabel.text = @"IB";
    [self.addressContainer addSubview:self.schemeLabel];

    self.addressField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.addressField.delegate = self;
    self.addressField.font = [IBTheme fontOfSize:15.0];
    self.addressField.textColor = [IBTheme text];
    self.addressField.tintColor = [IBTheme accent];
    self.addressField.placeholder = @"Busca o escribe una dirección";
    self.addressField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.addressField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.addressField.spellCheckingType = UITextSpellCheckingTypeNo;
    self.addressField.keyboardType = UIKeyboardTypeURL;
    self.addressField.returnKeyType = UIReturnKeyGo;
    self.addressField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.addressField.adjustsFontSizeToFitWidth = YES;
    self.addressField.minimumFontSize = 11.0;
    self.addressField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.addressContainer addSubview:self.addressField];

    self.bookmarkButton = [self chromeButtonWithTitle:@"\u2606" size:22.0];
    self.bookmarkButton.accessibilityLabel = @"Añadir a marcadores";
    [self.bookmarkButton addTarget:self
                            action:@selector(bookmarkTapped)
                  forControlEvents:UIControlEventTouchUpInside];
    [self.addressRow addSubview:self.bookmarkButton];

    self.menuButton = [self chromeButtonWithTitle:@"\u22EF" size:24.0];
    self.menuButton.accessibilityLabel = @"Menú";
    [self.menuButton addTarget:self
                        action:@selector(menuTapped)
              forControlEvents:UIControlEventTouchUpInside];
    [self.addressRow addSubview:self.menuButton];

    UIView *addressLine = [[UIView alloc] initWithFrame:CGRectZero];
    addressLine.tag = 902;
    addressLine.backgroundColor = [IBTheme chromeBorder];
    addressLine.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.chrome addSubview:addressLine];

    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    self.progressView.progressTintColor = [IBTheme accent];
    self.progressView.trackTintColor = [UIColor clearColor];
    self.progressView.hidden = YES;
    [self.addressRow addSubview:self.progressView];

    self.contentView = [[UIView alloc] initWithFrame:CGRectZero];
    self.contentView.backgroundColor = [UIColor whiteColor];
    self.contentView.clipsToBounds = YES;
    self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                         UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.contentView];

    self.errorView = [[IBErrorView alloc] initWithFrame:CGRectZero];
    __weak typeof(self) weakSelf = self;
    self.errorView.onRetry = ^{ [weakSelf reloadCurrentTab]; };
    self.errorView.onOpenSafari = ^{
        NSURL *url = [weakSelf currentTab].currentURL;
        if (url) { [weakSelf openExternally:url]; }
    };
    [self.contentView addSubview:self.errorView];

    self.toastLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.toastLabel.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.92];
    self.toastLabel.textColor = [UIColor whiteColor];
    self.toastLabel.font = [IBTheme mediumFontOfSize:13.0];
    self.toastLabel.textAlignment = NSTextAlignmentCenter;
    self.toastLabel.layer.cornerRadius = 14.0;
    self.toastLabel.clipsToBounds = YES;
    self.toastLabel.numberOfLines = 2;
    self.toastLabel.alpha = 0.0;
    self.toastLabel.hidden = YES;
    [self.view addSubview:self.toastLabel];
}

- (void)layoutChromeLines {
    UIView *tabLine = [self.tabBar viewWithTag:901];
    tabLine.frame = CGRectMake(0, self.tabBar.bounds.size.height - [IBTheme hairline],
                               self.tabBar.bounds.size.width, [IBTheme hairline]);

    UIView *addressLine = [self.chrome viewWithTag:902];
    addressLine.frame = CGRectMake(0, self.chrome.bounds.size.height - [IBTheme hairline],
                                   self.chrome.bounds.size.width, [IBTheme hairline]);
}

- (void)layoutChips {
    CGFloat y = MAX(0.0, (self.tabScrollView.bounds.size.height - IBKTabChipHeight) / 2.0);
    CGFloat x = 0.0;
    for (IBTabChipView *chip in self.chips) {
        CGFloat chipWidth = [chip preferredWidth];
        chip.frame = CGRectMake(x, y, chipWidth, IBKTabChipHeight);
        x += chipWidth + 4.0;
    }
    self.tabScrollView.contentSize = CGSizeMake(x, self.tabScrollView.bounds.size.height);

    if (self.currentIndex >= 0 && self.currentIndex < (NSInteger)self.chips.count) {
        IBTabChipView *selected = self.chips[(NSUInteger)self.currentIndex];
        [self.tabScrollView scrollRectToVisible:selected.frame animated:NO];
    }
}

- (void)layoutCurrentWebView {
    IBWebTab *tab = [self currentTab];
    if (tab.webView) {
        tab.webView.frame = self.contentView.bounds;
    }
}

- (void)layoutToast {
    if (self.toastLabel.hidden) { return; }
    CGSize maxSize = CGSizeMake(self.view.bounds.size.width - 80.0, 80.0);
    CGSize size = [self.toastLabel sizeThatFits:maxSize];
    CGFloat width = MIN(maxSize.width, MAX(150.0, size.width + 32.0));
    CGFloat height = MAX(30.0, size.height + 14.0);
    self.toastLabel.frame = CGRectMake((self.view.bounds.size.width - width) / 2.0,
                                       CGRectGetMaxY(self.contentView.frame) - height - 24.0,
                                       width, height);
}

#pragma mark - Pestañas

- (IBWebTab *)currentTab {
    if (self.currentIndex < 0 || self.currentIndex >= (NSInteger)self.tabs.count) {
        return nil;
    }
    return self.tabs[(NSUInteger)self.currentIndex];
}

- (NSInteger)createTabWithURL:(NSURL *)url makeCurrent:(BOOL)makeCurrent {
    IBWebTab *tab = [[IBWebTab alloc] initWithDelegate:self];
    tab.presentingViewController = self;
    if (url && [IBURLNormalizer isHTTPURL:url]) {
        [tab loadURL:url];
    } else {
        [tab loadStartPage];
    }
    [self.tabs addObject:tab];

    NSInteger index = (NSInteger)self.tabs.count - 1;
    if (makeCurrent) {
        self.currentIndex = index;
        [self attachCurrentTab];
        [self reloadTabChips];
        [self updateAddressBar];
        [self updateNavigationButtons];
    }
    return index;
}

- (void)attachCurrentTab {
    for (IBWebTab *tab in self.tabs) {
        if (tab.webView.superview == self.contentView) {
            [tab.webView removeFromSuperview];
        }
    }
    IBWebTab *tab = [self currentTab];
    if (!tab) { return; }

    [tab restoreIfNeeded];
    if (tab.webView && tab.webView.superview != self.contentView) {
        tab.webView.frame = self.contentView.bounds;
        [self.contentView insertSubview:tab.webView atIndex:0];
    }
    tab.presentingViewController = self;
}

- (void)selectTabAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.tabs.count) { return; }

    if (index == self.currentIndex) {
        [self attachCurrentTab];
        return;
    }

    self.currentIndex = index;
    [self attachCurrentTab];
    [self.errorView hide];
    [self reloadTabChips];
    [self updateAddressBar];
    [self updateNavigationButtons];
    [self updateProgressForCurrentTab];
    [self saveSession];
}

- (void)closeTabAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.tabs.count) { return; }

    IBWebTab *tab = self.tabs[(NSUInteger)index];
    [tab unload];
    [self.tabs removeObjectAtIndex:(NSUInteger)index];

    if (self.tabs.count == 0) {
        self.currentIndex = -1;
        [self createTabWithURL:nil makeCurrent:YES];
        [self saveSession];
        return;
    }

    if (index < self.currentIndex) {
        self.currentIndex--;
    } else if (index == self.currentIndex) {
        self.currentIndex = MIN(index, (NSInteger)self.tabs.count - 1);
    }

    [self attachCurrentTab];
    [self.errorView hide];
    [self reloadTabChips];
    [self updateAddressBar];
    [self updateNavigationButtons];
    [self updateProgressForCurrentTab];
    [self saveSession];
}

- (void)newTabTapped {
    [self createTabWithURL:nil makeCurrent:YES];
    [self saveSession];
    [self focusAddressField];
}

- (void)reloadTabChips {
    for (UIView *view in self.tabScrollView.subviews) {
        [view removeFromSuperview];
    }
    [self.chips removeAllObjects];

    __weak typeof(self) weakSelf = self;
    for (NSUInteger i = 0; i < self.tabs.count; i++) {
        IBWebTab *tab = self.tabs[i];
        IBTabChipView *chip = [[IBTabChipView alloc] initWithFrame:CGRectZero];
        chip.title = tab.title.length ? tab.title : @"Nueva pestaña";
        chip.selected = ((NSInteger)i == self.currentIndex);
        chip.loading = tab.loading;
        chip.onSelect = ^{ [weakSelf selectTabAtIndex:(NSInteger)i]; };
        chip.onClose = ^{ [weakSelf closeTabAtIndex:(NSInteger)i]; };
        [self.tabScrollView addSubview:chip];
        [self.chips addObject:chip];
    }
    [self layoutChips];
}

#pragma mark - Navegación

- (void)openURL:(NSURL *)url {
    if (!url) { return; }
    [self view];

    if ([IBURLNormalizer isStartURL:url]) {
        [[self currentTab] loadStartPage];
        [self.errorView hide];
        [self updateAddressBar];
        return;
    }

    if (![IBURLNormalizer isHTTPURL:url]) {
        [self openExternally:url];
        return;
    }

    IBWebTab *tab = [self currentTab];
    if (!tab) {
        [self createTabWithURL:url makeCurrent:YES];
    } else {
        [tab loadURL:url];
        [self attachCurrentTab];
    }
    [self.errorView hide];
    [self updateAddressBar];
    [self updateNavigationButtons];
    [self saveSession];
}

- (void)openURLInNewTab:(NSURL *)url {
    if (!url) { return; }
    [self view];
    if (![IBURLNormalizer isHTTPURL:url]) {
        [self openExternally:url];
        return;
    }
    [self createTabWithURL:url makeCurrent:YES];
    [self saveSession];
}

- (void)openExternally:(NSURL *)url {
    if (!url) { return; }
    AppDelegate *delegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    if ([delegate respondsToSelector:@selector(openExternalURL:)]) {
        [delegate openExternalURL:url];
    }
}

- (void)goBack {
    [[self currentTab] goBack];
    [self performSelector:@selector(updateNavigationButtons)
               withObject:nil
               afterDelay:0.25];
}

- (void)goForward {
    [[self currentTab] goForward];
    [self performSelector:@selector(updateNavigationButtons)
               withObject:nil
               afterDelay:0.25];
}

- (void)reloadTapped {
    IBWebTab *tab = [self currentTab];
    if (!tab) { return; }
    if (tab.loading) {
        [tab stopLoading];
        [self updateProgressForCurrentTab];
        [self updateReloadButton];
    } else {
        [tab reload];
        [self.errorView hide];
    }
}

- (void)reloadCurrentTab {
    [self.errorView hide];
    [[self currentTab] reload];
}

- (void)updateNavigationButtons {
    IBWebTab *tab = [self currentTab];
    self.backButton.enabled = [tab canGoBack];
    self.forwardButton.enabled = [tab canGoForward];
    self.reloadButton.enabled = (tab != nil);
    [self updateReloadButton];
    [self updateBookmarkButton];
}

- (void)updateReloadButton {
    IBWebTab *tab = [self currentTab];
    if (tab.loading) {
        [self.reloadButton setTitle:@"\u00D7" forState:UIControlStateNormal];
        self.reloadButton.accessibilityLabel = @"Detener";
    } else {
        [self.reloadButton setTitle:@"\u21BB" forState:UIControlStateNormal];
        self.reloadButton.accessibilityLabel = @"Recargar";
    }
}

- (void)updateProgressForCurrentTab {
    IBWebTab *tab = [self currentTab];
    if (!tab || tab.progress <= 0.0 || tab.progress >= 1.0) {
        self.progressView.hidden = YES;
        self.progressView.progress = 0.0;
    } else {
        self.progressView.hidden = NO;
        self.progressView.progress = (float)tab.progress;
    }
}

- (void)updateBookmarkButton {
    IBWebTab *tab = [self currentTab];
    NSURL *url = tab.currentURL;
    BOOL bookmarked = url ? [[IBBookmarkStore sharedStore] isBookmarkedURL:url] : NO;
    [self.bookmarkButton setTitle:bookmarked ? @"\u2605" : @"\u2606"
                         forState:UIControlStateNormal];
    [self.bookmarkButton setTitleColor:(bookmarked ? [IBTheme accent]
                                                  : [IBTheme secondaryText])
                              forState:UIControlStateNormal];
    self.bookmarkButton.enabled = (url != nil);
    self.bookmarkButton.accessibilityLabel = bookmarked
        ? @"Quitar de marcadores"
        : @"Añadir a marcadores";
}

- (void)bookmarkTapped {
    IBWebTab *tab = [self currentTab];
    NSURL *url = tab.currentURL;
    if (!url) {
        [self showToast:@"Abre una página para guardarla"];
        return;
    }
    BOOL added = [[IBBookmarkStore sharedStore] toggleBookmarkURL:url title:tab.title];
    [self updateBookmarkButton];
    [self showToast:added ? @"Añadido a marcadores" : @"Eliminado de marcadores"];
}

#pragma mark - Barra de direcciones

- (void)updateAddressBar {
    if (self.editingAddress) { return; }

    IBWebTab *tab = [self currentTab];
    NSURL *url = tab.currentURL ? tab.currentURL : tab.requestedURL;

    if (!tab || tab.isStartPage || !url) {
        self.addressField.text = @"";
        self.schemeLabel.text = [[IBSettings sharedSettings] privateMode] ? @"PRIV" : @"IB";
        self.schemeLabel.textColor = [[IBSettings sharedSettings] privateMode]
            ? [IBTheme accent]
            : [IBTheme tertiaryText];
        self.addressField.placeholder = [[IBSettings sharedSettings] privateMode]
            ? @"Búsqueda privada"
            : @"Busca o escribe una dirección";
    } else {
        self.addressField.text = url.absoluteString;
        BOOL secure = [[url.scheme lowercaseString] isEqualToString:@"https"];
        self.schemeLabel.text = secure ? @"https" : @"http";
        self.schemeLabel.textColor = secure
            ? [UIColor colorWithRed:0.09 green:0.48 blue:0.30 alpha:1.0]
            : [IBTheme tertiaryText];
        self.addressField.placeholder = @"Busca o escribe una dirección";
    }
    [self updateBookmarkButton];
}

- (void)focusAddressField {
    [self.addressField becomeFirstResponder];
    [self.addressField selectAll:nil];
}

- (void)navigateFromAddressField {
    NSString *text = [self.addressField.text stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0) { return; }

    NSURL *url = [IBURLNormalizer URLFromUserInput:text];
    if (!url) { return; }
    [self.addressField resignFirstResponder];
    [self openURL:url];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self navigateFromAddressField];
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    self.editingAddress = YES;
    self.addressContainer.layer.borderColor = [IBTheme accent].CGColor;

    IBWebTab *tab = [self currentTab];
    if (tab.currentURL) {
        textField.text = tab.currentURL.absoluteString;
    }
    [textField selectAll:nil];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    self.editingAddress = NO;
    self.addressContainer.layer.borderColor = [IBTheme fieldBorder].CGColor;
    [self updateAddressBar];
}

#pragma mark - Menú

- (void)menuTapped {
    UIAlertController *sheet = [UIAlertController
        alertControllerWithTitle:nil
                         message:nil
                  preferredStyle:UIAlertControllerStyleActionSheet];

    __weak typeof(self) weakSelf = self;

    [sheet addAction:[UIAlertAction actionWithTitle:@"Nueva pestaña"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [weakSelf createTabWithURL:nil makeCurrent:YES];
        [weakSelf focusAddressField];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Página de inicio"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [[weakSelf currentTab] loadStartPage];
        [weakSelf.errorView hide];
        [weakSelf updateAddressBar];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Marcadores"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [weakSelf showBookmarks];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Historial"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [weakSelf showHistory];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Descargas"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [weakSelf showDownloads];
    }]];

    IBWebTab *tab = [self currentTab];
    if (tab.currentURL && [IBURLNormalizer isHTTPURL:tab.currentURL]) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Modo lector"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            [weakSelf openReader];
        }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"Compartir…"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            [weakSelf shareCurrentPage];
        }]];
    }

    BOOL privateMode = [[IBSettings sharedSettings] privateMode];
    [sheet addAction:[UIAlertAction actionWithTitle:(privateMode
                                                     ? @"Desactivar modo privado"
                                                     : @"Activar modo privado")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [[IBSettings sharedSettings] setPrivateMode:!privateMode];
        [weakSelf showToast:privateMode ? @"Modo normal" : @"Modo privado activado"];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Ajustes"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [weakSelf showSettings];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Acerca de IBrowse"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [weakSelf showAbout];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Cerrar"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = self.menuButton;
        sheet.popoverPresentationController.sourceRect = self.menuButton.bounds;
        sheet.popoverPresentationController.permittedArrowDirections =
            UIPopoverArrowDirectionUp;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - Modales

- (UINavigationController *)wrapForPresentation:(UIViewController *)controller {
    UINavigationController *nav = [[UINavigationController alloc]
        initWithRootViewController:controller];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    nav.navigationBar.translucent = NO;
    nav.navigationBar.barTintColor = [IBTheme chrome];
    nav.navigationBar.tintColor = [IBTheme accent];
    [nav.navigationBar setTitleTextAttributes:@{
        NSForegroundColorAttributeName: [IBTheme text],
        NSFontAttributeName: [IBTheme boldFontOfSize:16.0]
    }];
    return nav;
}

- (void)showBookmarks {
    IBListViewController *list = [[IBListViewController alloc]
        initWithMode:IBListModeBookmarks];
    __weak typeof(self) weakSelf = self;
    list.onSelectEntry = ^(NSDictionary *entry, BOOL newTab) {
        NSURL *url = [NSURL URLWithString:entry[@"url"]];
        if (!url) { return; }
        if (newTab) {
            [weakSelf openURLInNewTab:url];
        } else {
            [weakSelf openURL:url];
        }
    };
    [self presentViewController:[self wrapForPresentation:list]
                       animated:YES
                     completion:nil];
}

- (void)showHistory {
    IBListViewController *list = [[IBListViewController alloc]
        initWithMode:IBListModeHistory];
    __weak typeof(self) weakSelf = self;
    list.onSelectEntry = ^(NSDictionary *entry, BOOL newTab) {
        NSURL *url = [NSURL URLWithString:entry[@"url"]];
        if (!url) { return; }
        if (newTab) {
            [weakSelf openURLInNewTab:url];
        } else {
            [weakSelf openURL:url];
        }
    };
    [self presentViewController:[self wrapForPresentation:list]
                       animated:YES
                     completion:nil];
}

- (void)showDownloads {
    IBDownloadsViewController *downloads = [[IBDownloadsViewController alloc] init];
    [self presentViewController:[self wrapForPresentation:downloads]
                       animated:YES
                     completion:nil];
}

- (void)showSettings {
    IBSettingsViewController *settings = [[IBSettingsViewController alloc] init];
    [self presentViewController:[self wrapForPresentation:settings]
                       animated:YES
                     completion:nil];
}

- (void)showAbout {
    IBAboutViewController *about = [[IBAboutViewController alloc] init];
    [self presentViewController:[self wrapForPresentation:about]
                       animated:YES
                     completion:nil];
}

- (void)shareCurrentPage {
    IBWebTab *tab = [self currentTab];
    if (!tab.currentURL) { return; }

    NSString *title = tab.title.length ? tab.title : tab.currentURL.absoluteString;
    UIActivityViewController *activity = [[UIActivityViewController alloc]
        initWithActivityItems:@[title, tab.currentURL]
        applicationActivities:nil];
    if (activity.popoverPresentationController) {
        activity.popoverPresentationController.sourceView = self.menuButton;
        activity.popoverPresentationController.sourceRect = self.menuButton.bounds;
        activity.popoverPresentationController.permittedArrowDirections =
            UIPopoverArrowDirectionUp;
    }
    [self presentViewController:activity animated:YES completion:nil];
}

- (void)openReader {
    IBWebTab *tab = [self currentTab];
    if (!tab || !tab.currentURL) {
        [self showToast:@"Abre un artículo para usar el lector"];
        return;
    }

    [self showToast:@"Preparando el modo lector…"];
    __weak typeof(self) weakSelf = self;
    [tab evaluateReaderWithCompletion:^(NSDictionary *result) {
        NSString *text = result[@"text"];
        if (![text isKindOfClass:[NSString class]] || text.length < 80) {
            [weakSelf showToast:@"Esta página no tiene un artículo legible"];
            return;
        }
        IBReaderViewController *reader = [[IBReaderViewController alloc]
            initWithArticle:result];
        reader.onOpenURL = ^(NSURL *url) {
            [weakSelf dismissViewControllerAnimated:YES completion:^{
                [weakSelf openURLInNewTab:url];
            }];
        };
        reader.modalPresentationStyle = UIModalPresentationFullScreen;
        reader.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        [weakSelf presentViewController:reader animated:YES completion:nil];
    }];
}

#pragma mark - Ajustes y privacidad

- (void)settingsDidChange:(NSNotification *)notification {
    IBSettings *settings = [IBSettings sharedSettings];

    for (IBWebTab *tab in self.tabs) {
        [tab refreshUserScripts];
        tab.webView.customUserAgent = settings.userAgentString;
    }

    if (settings.privateMode != self.lastPrivateMode) {
        self.lastPrivateMode = settings.privateMode;
        [self rebuildTabsForPrivacyChange];
    }

    [self updatePrivateLook];
    [self updateAddressBar];
    [self reloadTabChips];
}

- (void)updatePrivateLook {
    BOOL privateMode = [[IBSettings sharedSettings] privateMode];
    self.addressRow.backgroundColor = privateMode
        ? [UIColor colorWithRed:0.955 green:0.945 blue:0.995 alpha:1.0]
        : [IBTheme chrome];
    self.schemeLabel.textColor = privateMode ? [IBTheme accent] : [IBTheme tertiaryText];
    [self updateAddressBar];
}

- (void)rebuildTabsForPrivacyChange {
    NSMutableArray *urls = [NSMutableArray array];
    NSInteger selected = self.currentIndex;

    for (IBWebTab *tab in self.tabs) {
        NSString *value = tab.currentURL.absoluteString;
        [urls addObject:value ? value : @""];
        [tab unload];
    }
    [self.tabs removeAllObjects];

    for (NSUInteger i = 0; i < urls.count; i++) {
        NSString *value = urls[i];
        NSURL *url = value.length ? [NSURL URLWithString:value] : nil;

        IBWebTab *tab = [[IBWebTab alloc] initWithDelegate:self];
        tab.presentingViewController = self;
        if (url) {
            [tab loadURL:url];
        } else {
            [tab loadStartPage];
        }
        [self.tabs addObject:tab];
    }

    if (self.tabs.count == 0) {
        self.currentIndex = -1;
        [self createTabWithURL:nil makeCurrent:YES];
        return;
    }

    self.currentIndex = MIN(MAX(0, selected), (NSInteger)self.tabs.count - 1);
    for (NSUInteger i = 0; i < self.tabs.count; i++) {
        if ((NSInteger)i != self.currentIndex) {
            [(IBWebTab *)self.tabs[i] unload];
        }
    }
    [self attachCurrentTab];
    [self reloadTabChips];
    [self updateAddressBar];
    [self updateNavigationButtons];
}

#pragma mark - Sesión

- (void)saveSession {
    IBSettings *settings = [IBSettings sharedSettings];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if (settings.privateMode || !settings.restoreSession) {
        [defaults removeObjectForKey:@"IBSessionTabs"];
        [defaults removeObjectForKey:@"IBSessionIndex"];
        return;
    }

    NSMutableArray *urls = [NSMutableArray array];
    for (IBWebTab *tab in self.tabs) {
        NSString *value = tab.currentURL.absoluteString;
        [urls addObject:value ? value : @""];
    }
    [defaults setObject:urls forKey:@"IBSessionTabs"];
    [defaults setInteger:self.currentIndex forKey:@"IBSessionIndex"];
    [defaults synchronize];
}

- (void)restoreSession {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *saved = [defaults arrayForKey:@"IBSessionTabs"];
    if (![saved isKindOfClass:[NSArray class]] || saved.count == 0) { return; }

    NSInteger selected = [defaults integerForKey:@"IBSessionIndex"];
    if (selected < 0 || selected >= (NSInteger)saved.count) { selected = 0; }

    for (id value in saved) {
        if (![value isKindOfClass:[NSString class]]) { continue; }
        NSURL *url = [(NSString *)value length]
            ? [NSURL URLWithString:value]
            : nil;

        IBWebTab *tab = [[IBWebTab alloc] initWithDelegate:self];
        tab.presentingViewController = self;
        if (url) {
            [tab loadURL:url];
        } else {
            [tab loadStartPage];
        }
        [self.tabs addObject:tab];
    }

    if (self.tabs.count == 0) { return; }

    self.currentIndex = MIN(MAX(0, selected), (NSInteger)self.tabs.count - 1);
    for (NSUInteger i = 0; i < self.tabs.count; i++) {
        if ((NSInteger)i != self.currentIndex) {
            [(IBWebTab *)self.tabs[i] unload];
        }
    }
}

#pragma mark - Avisos

- (void)showToast:(NSString *)message {
    if (message.length == 0) { return; }

    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(hideToast)
                                               object:nil];

    self.toastLabel.text = message;
    self.toastLabel.hidden = NO;
    self.toastLabel.alpha = 0.0;
    [self layoutToast];
    [self.view bringSubviewToFront:self.toastLabel];

    [UIView animateWithDuration:0.18
                     animations:^{
        self.toastLabel.alpha = 1.0;
    }];
    [self performSelector:@selector(hideToast)
               withObject:nil
               afterDelay:2.4];
}

- (void)hideToast {
    [UIView animateWithDuration:0.28
                     animations:^{
        self.toastLabel.alpha = 0.0;
    } completion:^(BOOL finished) {
        self.toastLabel.hidden = YES;
    }];
}

#pragma mark - IBWebTabDelegate

- (void)webTabDidStartLoading:(IBWebTab *)tab {
    if (tab == [self currentTab]) {
        [self.errorView hide];
        [self updateReloadButton];
        [self updateProgressForCurrentTab];
    }
    [self reloadTabChips];
}

- (void)webTabDidFinishLoading:(IBWebTab *)tab {
    if (tab == [self currentTab]) {
        self.progressView.hidden = YES;
        self.progressView.progress = 0.0;
        [self updateAddressBar];
        [self updateNavigationButtons];
    }

    if (![[IBSettings sharedSettings] privateMode] &&
        tab.currentURL && [IBURLNormalizer isHTTPURL:tab.currentURL]) {
        [[IBHistoryStore sharedStore] addEntryWithURL:tab.currentURL
                                                title:tab.title];
    }

    [self reloadTabChips];
    [self saveSession];
}

- (void)webTab:(IBWebTab *)tab didFailWithError:(NSError *)error {
    if (tab != [self currentTab]) { return; }

    NSString *message = error.localizedDescription;
    if (message.length == 0) {
        message = @"No se pudo conectar con el servidor.";
    }

    NSString *hint = @"Comprueba la conexión y que la dirección sea correcta.";
    if ([error.domain isEqualToString:NSURLErrorDomain]) {
        if (error.code == NSURLErrorTimedOut) {
            hint = @"El servidor no respondió en 30 segundos. "
                    "Comprueba que la web del router esté activada.";
        } else if (error.code == NSURLErrorCannotConnectToHost ||
                   error.code == NSURLErrorNetworkConnectionLost ||
                   error.code == NSURLErrorNotConnectedToInternet) {
            hint = @"No hay conexión con ese servidor. Revisa el WiFi "
                    "y que la IP sea la del router.";
        } else if (error.code == NSURLErrorServerCertificateUntrusted ||
                   error.code == NSURLErrorSecureConnectionFailed) {
            hint = @"El certificado del router no es válido. Prueba con "
                    "http:// delante de la dirección.";
        }
    }

    NSString *detail = [NSString stringWithFormat:@"\n\n(%@ %ld)",
                        error.domain, (long)error.code];
    [self.errorView showWithTitle:@"No se pudo cargar la página"
                          message:[NSString stringWithFormat:@"%@\n\n%@%@",
                                   message, hint, detail]];
    self.progressView.hidden = YES;
    [self updateReloadButton];
}

- (void)webTabDidUpdateTitle:(IBWebTab *)tab {
    [self reloadTabChips];
    if (tab == [self currentTab]) {
        [self updateBookmarkButton];
    }
}

- (void)webTabDidUpdateURL:(IBWebTab *)tab {
    if (tab == [self currentTab]) {
        [self updateAddressBar];
        [self updateNavigationButtons];
    }
    [self reloadTabChips];
}

- (void)webTabDidUpdateProgress:(IBWebTab *)tab {
    if (tab != [self currentTab]) { return; }
    if (tab.progress >= 1.0) {
        self.progressView.hidden = YES;
    } else if (tab.progress > 0.0) {
        self.progressView.hidden = NO;
        self.progressView.progress = (float)tab.progress;
    }
    [self updateReloadButton];
}

- (void)webTab:(IBWebTab *)tab requestOpenURLInNewTab:(NSURL *)url {
    [self openURLInNewTab:url];
}

- (void)webTab:(IBWebTab *)tab requestOpenExternalURL:(NSURL *)url {
    [self openExternally:url];
}

- (void)webTab:(IBWebTab *)tab
    requestDownloadURL:(NSURL *)url
        suggestedName:(NSString *)name {
    [[IBDownloadManager sharedManager] startDownloadFromURL:url suggestedName:name];
    [self showToast:[NSString stringWithFormat:@"Descargando %@",
                     name.length ? name : @"archivo"]];
}

- (void)webTab:(IBWebTab *)tab requestSearch:(NSString *)query {
    NSURL *url = [IBURLNormalizer URLFromUserInput:query];
    if (url) { [self openURL:url]; }
}

- (void)webTabDidRequestFocusAddress:(IBWebTab *)tab {
    [self focusAddressField];
}

@end
