#import "IBWebTab.h"
#import "IBContentBlocker.h"
#import "IBSettings.h"
#import "IBURLNormalizer.h"
#import "IBTheme.h"

@interface IBWeakScriptMessageHandler : NSObject <WKScriptMessageHandler>
@property (nonatomic, weak) id<WKScriptMessageHandler> target;
- (instancetype)initWithTarget:(id<WKScriptMessageHandler>)target;
@end

@implementation IBWeakScriptMessageHandler
- (instancetype)initWithTarget:(id<WKScriptMessageHandler>)target {
    self = [super init];
    if (self) { _target = target; }
    return self;
}
- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    [self.target userContentController:userContentController
               didReceiveScriptMessage:message];
}
@end

@interface IBWebTab () <WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler>

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) NSURL *currentURL;
@property (nonatomic, strong) NSURL *requestedURL;
@property (nonatomic, assign) BOOL isStartPage;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) double progress;
@property (nonatomic, assign) BOOL observing;

@end

@implementation IBWebTab

+ (WKProcessPool *)sharedProcessPool {
    static WKProcessPool *pool = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pool = [[WKProcessPool alloc] init];
    });
    return pool;
}

- (instancetype)initWithDelegate:(id<IBWebTabDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
        _title = @"Nueva pestaña";
        _progress = 0.0;
        _loading = NO;
        _isStartPage = NO;
    }
    return self;
}

- (void)dealloc {
    if (_observing && _webView) {
        [_webView removeObserver:self forKeyPath:@"estimatedProgress"];
        [_webView removeObserver:self forKeyPath:@"title"];
        [_webView removeObserver:self forKeyPath:@"loading"];
    }
    _webView.navigationDelegate = nil;
    _webView.UIDelegate = nil;
    [_webView stopLoading];
    [_webView removeFromSuperview];
}

#pragma mark - WebView creation

- (void)createWebViewIfNeeded {
    if (self.webView) { return; }

    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    configuration.processPool = [[self class] sharedProcessPool];
    configuration.preferences.javaScriptEnabled = YES;
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = YES;
    configuration.allowsInlineMediaPlayback = YES;
    configuration.requiresUserActionForMediaPlayback = NO;

    IBSettings *settings = [IBSettings sharedSettings];
    configuration.websiteDataStore = settings.privateMode
        ? [WKWebsiteDataStore nonPersistentDataStore]
        : [WKWebsiteDataStore defaultDataStore];

    WKUserContentController *controller = [[WKUserContentController alloc] init];
    configuration.userContentController = controller;

    IBWeakScriptMessageHandler *proxy =
        [[IBWeakScriptMessageHandler alloc] initWithTarget:self];
    [controller addScriptMessageHandler:proxy name:@"ibrowse"];

    [self installScriptsInController:controller];

    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero
                                            configuration:configuration];
    webView.navigationDelegate = self;
    webView.UIDelegate = self;
    webView.customUserAgent = settings.userAgentString;
    webView.allowsBackForwardNavigationGestures = YES;
    webView.opaque = YES;
    webView.backgroundColor = [UIColor whiteColor];
    webView.scrollView.backgroundColor = [UIColor whiteColor];
    webView.scrollView.bounces = YES;
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                               UIViewAutoresizingFlexibleHeight;

    [webView addObserver:self
              forKeyPath:@"estimatedProgress"
                 options:NSKeyValueObservingOptionNew
                 context:NULL];
    [webView addObserver:self
              forKeyPath:@"title"
                 options:NSKeyValueObservingOptionNew
                 context:NULL];
    [webView addObserver:self
              forKeyPath:@"loading"
                 options:NSKeyValueObservingOptionNew
                 context:NULL];
    self.observing = YES;

    self.webView = webView;
}

- (void)installScriptsInController:(WKUserContentController *)controller {
    [controller removeAllUserScripts];

    IBSettings *settings = [IBSettings sharedSettings];

    if (settings.compatibilityMode) {
        NSString *polyfills = [IBContentBlocker polyfillSource];
        if (polyfills.length) {
            WKUserScript *script = [[WKUserScript alloc]
                initWithSource:polyfills
                 injectionTime:WKUserScriptInjectionTimeAtDocumentStart
              forMainFrameOnly:NO];
            [controller addUserScript:script];
        }
    }

    if (settings.blockAds || settings.blockTrackers) {
        NSString *blocker = [IBContentBlocker blockerSourceWithAds:settings.blockAds
                                                         trackers:settings.blockTrackers];
        if (blocker.length) {
            WKUserScript *script = [[WKUserScript alloc]
                initWithSource:blocker
                 injectionTime:WKUserScriptInjectionTimeAtDocumentStart
              forMainFrameOnly:NO];
            [controller addUserScript:script];
        }
    }

    NSString *bridge = [IBContentBlocker bridgeSource];
    if (bridge.length) {
        WKUserScript *script = [[WKUserScript alloc]
            initWithSource:bridge
             injectionTime:WKUserScriptInjectionTimeAtDocumentStart
          forMainFrameOnly:NO];
        [controller addUserScript:script];
    }
}

- (void)refreshUserScripts {
    if (!self.webView) { return; }
    [self installScriptsInController:self.webView.configuration.userContentController];
}

#pragma mark - Loading

- (void)loadURL:(NSURL *)url {
    if (!url) { return; }
    if ([IBURLNormalizer isStartURL:url]) {
        [self loadStartPage];
        return;
    }

    [self createWebViewIfNeeded];
    self.isStartPage = NO;

    IBSettings *settings = [IBSettings sharedSettings];
    NSURL *logicalURL = url;
    if (settings.relayEnabled && settings.isRelayConfigured &&
        [IBURLNormalizer isRelayURL:url baseURL:settings.relayBaseURL]) {
        NSURL *original = [IBURLNormalizer originalURLFromRelayURL:url
                                                           baseURL:settings.relayBaseURL];
        if (original) { logicalURL = original; }
    }

    self.currentURL = logicalURL;
    self.title = [IBURLNormalizer displayHostForURL:logicalURL];

    NSURL *target = url;
    if (settings.relayEnabled && settings.isRelayConfigured &&
        [IBURLNormalizer isHTTPURL:url]) {
        NSString *wrapped = [IBURLNormalizer relayWrappedURLString:url
                                                           baseURL:settings.relayBaseURL];
        if (wrapped) {
            target = [NSURL URLWithString:wrapped];
        }
    }

    self.requestedURL = target;
    self.webView.customUserAgent = settings.userAgentString;

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:target
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:90.0];
    [request setValue:settings.userAgentString forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"es-ES,es;q=0.9,en;q=0.8" forHTTPHeaderField:@"Accept-Language"];
    [self.webView loadRequest:request];
    [self.delegate webTabDidUpdateURL:self];
}

- (void)loadStartPage {
    [self createWebViewIfNeeded];
    self.isStartPage = YES;
    self.currentURL = nil;
    self.requestedURL = nil;
    self.title = @"Inicio";
    self.progress = 0.0;
    self.loading = NO;

    NSString *path = [[NSBundle mainBundle] pathForResource:@"start" ofType:@"html"];
    NSString *html = path ? [NSString stringWithContentsOfFile:path
                                                     encoding:NSUTF8StringEncoding
                                                        error:NULL] : nil;
    if (!html.length) {
        html = @"<html><head><meta name='viewport' content='width=device-width'>"
                "</head><body style='font-family:-apple-system;padding:40px'>"
                "<h1>IBrowse</h1><p>No se encontró la página de inicio.</p>"
                "</body></html>";
    }
    NSURL *baseURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]
                                isDirectory:YES];
    [self.webView loadHTMLString:html baseURL:baseURL];
    [self.delegate webTabDidUpdateURL:self];
}

- (void)reload {
    if (!self.webView) {
        [self restoreIfNeeded];
        return;
    }
    if (self.isStartPage) {
        [self loadStartPage];
        return;
    }
    if (self.webView.URL) {
        [self.webView reload];
    } else if (self.requestedURL) {
        [self loadURL:self.currentURL ? self.currentURL : self.requestedURL];
    }
}

- (void)stopLoading {
    [self.webView stopLoading];
    self.loading = NO;
}

- (void)goBack {
    if ([self.webView canGoBack]) { [self.webView goBack]; }
}

- (void)goForward {
    if ([self.webView canGoForward]) { [self.webView goForward]; }
}

- (BOOL)canGoBack { return self.webView ? self.webView.canGoBack : NO; }
- (BOOL)canGoForward { return self.webView ? self.webView.canGoForward : NO; }

- (void)unload {
    if (!self.webView) { return; }

    if (!self.isStartPage && self.webView.URL) {
        IBSettings *settings = [IBSettings sharedSettings];
        if (![IBURLNormalizer isRelayURL:self.webView.URL baseURL:settings.relayBaseURL]) {
            self.currentURL = self.webView.URL;
        }
        self.requestedURL = self.webView.URL;
    }

    if (self.observing) {
        [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
        [self.webView removeObserver:self forKeyPath:@"title"];
        [self.webView removeObserver:self forKeyPath:@"loading"];
        self.observing = NO;
    }
    self.webView.navigationDelegate = nil;
    self.webView.UIDelegate = nil;
    [self.webView stopLoading];
    [self.webView removeFromSuperview];
    self.webView = nil;
    self.loading = NO;
}

- (void)restoreIfNeeded {
    if (self.webView) { return; }
    [self createWebViewIfNeeded];
    if (self.isStartPage || !self.requestedURL) {
        [self loadStartPage];
        return;
    }
    self.webView.customUserAgent = [[IBSettings sharedSettings] userAgentString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.requestedURL
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:90.0];
    [request setValue:[[IBSettings sharedSettings] userAgentString]
   forHTTPHeaderField:@"User-Agent"];
    [self.webView loadRequest:request];
}

#pragma mark - Reader

- (void)evaluateReaderWithCompletion:(void (^)(NSDictionary *result))completion {
    if (!self.webView) {
        if (completion) { completion(nil); }
        return;
    }
    NSString *source = [IBContentBlocker readerSource];
    if (!source.length) {
        if (completion) { completion(nil); }
        return;
    }
    [self.webView evaluateJavaScript:source
                   completionHandler:^(id result, NSError *error) {
        if (completion) {
            if (!error && [result isKindOfClass:[NSDictionary class]]) {
                completion((NSDictionary *)result);
            } else {
                completion(nil);
            }
        }
    }];
}

#pragma mark - Title / state

- (void)setTitle:(NSString *)title {
    NSString *clean = [title stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (clean.length == 0) {
        clean = self.isStartPage ? @"Inicio" : @"Nueva pestaña";
    }
    if ([_title isEqualToString:clean]) { return; }
    _title = [clean copy];
    [self.delegate webTabDidUpdateTitle:self];
}

- (void)setCurrentURL:(NSURL *)currentURL {
    if ((_currentURL == currentURL) ||
        [_currentURL.absoluteString isEqualToString:currentURL.absoluteString]) {
        return;
    }
    _currentURL = currentURL;
    [self.delegate webTabDidUpdateURL:self];
}

- (void)updateLogicalURLFromString:(NSString *)value {
    if (![value isKindOfClass:[NSString class]] || value.length == 0) { return; }
    NSURL *url = [NSURL URLWithString:value];
    if ([IBURLNormalizer isHTTPURL:url]) {
        self.currentURL = url;
    }
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if (object != self.webView) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }

    if ([keyPath isEqualToString:@"estimatedProgress"]) {
        _progress = [[change objectForKey:NSKeyValueChangeNewKey] doubleValue];
        [self.delegate webTabDidUpdateProgress:self];
    } else if ([keyPath isEqualToString:@"title"]) {
        NSString *value = [change objectForKey:NSKeyValueChangeNewKey];
        if ([value isKindOfClass:[NSString class]] && value.length) {
            [self setTitle:self.isStartPage ? @"Inicio" : value];
        }
    } else if ([keyPath isEqualToString:@"loading"]) {
        _loading = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
    }
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    self.loading = YES;
    self.progress = 0.0;
    [self.delegate webTabDidStartLoading:self];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.loading = NO;
    self.progress = 1.0;

    if (self.isStartPage) {
        _title = @"Inicio";
        _currentURL = nil;
    } else {
        IBSettings *settings = [IBSettings sharedSettings];
        NSURL *webURL = webView.URL;
        if (settings.relayEnabled && settings.isRelayConfigured &&
            [IBURLNormalizer isRelayURL:webURL baseURL:settings.relayBaseURL]) {
            NSURL *logical = [IBURLNormalizer originalURLFromRelayURL:webURL
                                                              baseURL:settings.relayBaseURL];
            if (logical) {
                _currentURL = logical;
            }
        } else if (webURL) {
            _currentURL = webURL;
            self.requestedURL = webURL;
        }
        if (_title.length == 0 || [_title isEqualToString:@"Inicio"] ||
            [_title isEqualToString:@"Nueva pestaña"]) {
            if (_currentURL) {
                _title = [IBURLNormalizer displayHostForURL:_currentURL];
            }
        }
    }

    [self.delegate webTabDidUpdateTitle:self];
    [self.delegate webTabDidUpdateURL:self];
    [self.delegate webTabDidFinishLoading:self];
}

- (void)webView:(WKWebView *)webView
    didFailProvisionalNavigation:(WKNavigation *)navigation
                       withError:(NSError *)error {
    [self handleNavigationError:error];
}

- (void)webView:(WKWebView *)webView
    didFailNavigation:(WKNavigation *)navigation
            withError:(NSError *)error {
    [self handleNavigationError:error];
}

- (void)handleNavigationError:(NSError *)error {
    self.loading = NO;

    if ([error.domain isEqualToString:NSURLErrorDomain] &&
        error.code == NSURLErrorCancelled) {
        return;
    }
    if ([error.domain isEqualToString:@"WebKitErrorDomain"] &&
        (error.code == 102 || error.code == 101)) {
        return;
    }
    [self.delegate webTab:self didFailWithError:error];
}

- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;
    if (!url) {
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }

    NSString *scheme = [url.scheme lowercaseString];

    if ([IBURLNormalizer isStartURL:url]) {
        [self loadStartPage];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }

    BOOL isWebScheme = [scheme isEqualToString:@"http"] ||
                       [scheme isEqualToString:@"https"] ||
                       [scheme isEqualToString:@"file"] ||
                       [scheme isEqualToString:@"about"];
    if (!isWebScheme) {
        [self.delegate webTab:self requestOpenExternalURL:url];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }

    if (navigationAction.targetFrame == nil) {
        if ([IBURLNormalizer isHTTPURL:url]) {
            [self.delegate webTab:self requestOpenURLInNewTab:url];
        }
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }

    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse
                     decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    NSURLResponse *response = navigationResponse.response;
    if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
        decisionHandler(WKNavigationResponsePolicyAllow);
        return;
    }

    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSString *disposition = [self headerValue:@"Content-Disposition"
                                     response:httpResponse];
    NSString *mime = [response.MIMEType lowercaseString];

    BOOL attachment = disposition &&
        [disposition rangeOfString:@"attachment"
                           options:NSCaseInsensitiveSearch].location != NSNotFound;

    NSArray *downloadTypes = @[
        @"application/octet-stream",
        @"application/zip",
        @"application/x-zip-compressed",
        @"application/x-ipa",
        @"application/vnd.android.package-archive",
        @"application/x-apple-diskimage",
        @"application/x-msdownload",
        @"application/macbinary",
        @"application/x-7z-compressed",
        @"application/x-rar-compressed",
        @"application/gzip",
        @"application/x-gzip",
        @"application/x-tar"
    ];

    BOOL isDownload = attachment || (mime && [downloadTypes containsObject:mime]);

    if (isDownload && response.URL) {
        decisionHandler(WKNavigationResponsePolicyCancel);
        NSString *name = [self filenameFromDisposition:disposition
                                                    url:response.URL];
        [self.delegate webTab:self
           requestDownloadURL:response.URL
               suggestedName:name];
        return;
    }

    decisionHandler(WKNavigationResponsePolicyAllow);
}

- (NSString *)headerValue:(NSString *)name response:(NSHTTPURLResponse *)response {
    for (id key in response.allHeaderFields) {
        if ([[key description] caseInsensitiveCompare:name] == NSOrderedSame) {
            return [response.allHeaderFields objectForKey:key];
        }
    }
    return nil;
}

- (NSString *)filenameFromDisposition:(NSString *)disposition url:(NSURL *)url {
    NSString *name = nil;
    if (disposition) {
        NSRange starRange = [disposition rangeOfString:@"filename*="
                                               options:NSCaseInsensitiveSearch];
        if (starRange.location != NSNotFound) {
            NSString *tail = [disposition substringFromIndex:NSMaxRange(starRange)];
            NSRange semi = [tail rangeOfString:@";"];
            if (semi.location != NSNotFound) {
                tail = [tail substringToIndex:semi.location];
            }
            tail = [tail stringByTrimmingCharactersInSet:
                    [NSCharacterSet whitespaceAndNewlineCharacterSet]];
            tail = [tail stringByTrimmingCharactersInSet:
                    [NSCharacterSet characterSetWithCharactersInString:@"\"'"]];
            NSRange quote = [tail rangeOfString:@"''"];
            if (quote.location != NSNotFound) {
                tail = [tail substringFromIndex:NSMaxRange(quote)];
            }
            name = [tail stringByRemovingPercentEncoding];
        }
        if (!name.length) {
            NSRange plain = [disposition rangeOfString:@"filename="
                                               options:NSCaseInsensitiveSearch];
            if (plain.location != NSNotFound) {
                NSString *tail = [disposition substringFromIndex:NSMaxRange(plain)];
                NSRange semi = [tail rangeOfString:@";"];
                if (semi.location != NSNotFound) {
                    tail = [tail substringToIndex:semi.location];
                }
                tail = [tail stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
                tail = [tail stringByTrimmingCharactersInSet:
                        [NSCharacterSet characterSetWithCharactersInString:@"\"'"]];
                name = [tail stringByRemovingPercentEncoding];
            }
        }
    }

    if (!name.length) {
        name = [url lastPathComponent];
    }
    if (!name.length) {
        name = @"descarga";
    }
    return name;
}

- (void)webView:(WKWebView *)webView
    didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
                    completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition,
                                                NSURLCredential *))completionHandler {
    NSString *method = challenge.protectionSpace.authenticationMethod;
    if (![method isEqualToString:NSURLAuthenticationMethodHTTPBasic] &&
        ![method isEqualToString:NSURLAuthenticationMethodHTTPDigest]) {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
        return;
    }

    UIViewController *presenter = [self topPresenter];
    if (!presenter) {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
        return;
    }

    NSString *host = challenge.protectionSpace.host ?: @"";
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Inicio de sesión"
                         message:host
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Usuario";
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Contraseña";
        textField.secureTextEntry = YES;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction *action) {
        completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Entrar"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        NSString *user = alert.textFields[0].text ?: @"";
        NSString *password = alert.textFields[1].text ?: @"";
        NSURLCredential *credential =
            [NSURLCredential credentialWithUser:user
                                       password:password
                                    persistence:NSURLCredentialPersistenceForSession];
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

#pragma mark - WKUIDelegate

- (void)webView:(WKWebView *)webView
    runJavaScriptAlertPanelWithMessage:(NSString *)message
                      initiatedByFrame:(WKFrameInfo *)frame
                     completionHandler:(void (^)(void))completionHandler {
    UIViewController *presenter = [self topPresenter];
    if (!presenter) { completionHandler(); return; }
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Aviso de la página"
                         message:message
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Aceptar"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        completionHandler();
    }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

- (void)webView:(WKWebView *)webView
    runJavaScriptConfirmPanelWithMessage:(NSString *)message
                        initiatedByFrame:(WKFrameInfo *)frame
                       completionHandler:(void (^)(BOOL))completionHandler {
    UIViewController *presenter = [self topPresenter];
    if (!presenter) { completionHandler(NO); return; }
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Confirmar"
                         message:message
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction *action) {
        completionHandler(NO);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Aceptar"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        completionHandler(YES);
    }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

- (void)webView:(WKWebView *)webView
    runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt
                              defaultText:(NSString *)defaultText
                         initiatedByFrame:(WKFrameInfo *)frame
                        completionHandler:(void (^)(NSString *))completionHandler {
    UIViewController *presenter = [self topPresenter];
    if (!presenter) { completionHandler(nil); return; }
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"La página pregunta"
                         message:prompt
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = defaultText;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction *action) {
        completionHandler(nil);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Aceptar"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        completionHandler(alert.textFields[0].text);
    }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

- (WKWebView *)webView:(WKWebView *)webView
    createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
               forNavigationAction:(WKNavigationAction *)navigationAction
                    windowFeatures:(WKWindowFeatures *)windowFeatures {
    NSURL *url = navigationAction.request.URL;
    if (url && [IBURLNormalizer isHTTPURL:url]) {
        [self.delegate webTab:self requestOpenURLInNewTab:url];
    }
    return nil;
}

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:@"ibrowse"]) { return; }
    id body = message.body;
    if (![body isKindOfClass:[NSDictionary class]]) { return; }

    NSString *type = body[@"type"];
    if (![type isKindOfClass:[NSString class]]) { return; }

    if ([type isEqualToString:@"logicalURL"]) {
        [self updateLogicalURLFromString:body[@"url"]];
    } else if ([type isEqualToString:@"search"]) {
        NSString *query = body[@"q"];
        if (query.length) {
            [self.delegate webTab:self requestSearch:query];
        }
    } else if ([type isEqualToString:@"navigate"]) {
        NSString *value = body[@"url"];
        if (value.length) {
            NSURL *url = [NSURL URLWithString:value];
            if (url) { [self loadURL:url]; }
        }
    } else if ([type isEqualToString:@"open"]) {
        NSString *value = body[@"url"];
        NSURL *url = value.length ? [NSURL URLWithString:value] : nil;
        if (url) { [self.delegate webTab:self requestOpenURLInNewTab:url]; }
    } else if ([type isEqualToString:@"external"]) {
        NSString *value = body[@"url"];
        NSURL *url = value.length ? [NSURL URLWithString:value] : nil;
        if (url) { [self.delegate webTab:self requestOpenExternalURL:url]; }
    } else if ([type isEqualToString:@"download"]) {
        NSString *value = body[@"url"];
        NSURL *url = value.length ? [NSURL URLWithString:value] : nil;
        if (url) {
            NSString *name = body[@"filename"];
            [self.delegate webTab:self
               requestDownloadURL:url
                   suggestedName:[name isKindOfClass:[NSString class]] ? name : nil];
        }
    } else if ([type isEqualToString:@"focusAddress"]) {
        [self.delegate webTabDidRequestFocusAddress:self];
    }
}

#pragma mark - Helpers

- (UIViewController *)topPresenter {
    UIViewController *presenter = self.presentingViewController;
    while (presenter.presentedViewController) {
        presenter = presenter.presentedViewController;
    }
    if (!presenter) {
        presenter = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (presenter.presentedViewController) {
            presenter = presenter.presentedViewController;
        }
    }
    return presenter;
}

@end
