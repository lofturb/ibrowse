#import "IBReaderViewController.h"
#import "IBTheme.h"
#import "IBURLNormalizer.h"
#import <WebKit/WebKit.h>

static const CGFloat IBKReaderBarHeight = 50.0;

@interface IBReaderViewController () <WKNavigationDelegate>

@property (nonatomic, strong) NSDictionary *article;
@property (nonatomic, strong) UIView *topBar;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIButton *shareButton;
@property (nonatomic, strong) WKWebView *webView;

@end

@implementation IBReaderViewController

- (instancetype)initWithArticle:(NSDictionary *)article {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _article = [article copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [IBTheme paper];

    self.topBar = [[UIView alloc] initWithFrame:CGRectZero];
    self.topBar.backgroundColor = [IBTheme chrome];
    [self.view addSubview:self.topBar];

    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.closeButton setTitle:@"Cerrar" forState:UIControlStateNormal];
    [self.closeButton setTitleColor:[IBTheme accent] forState:UIControlStateNormal];
    self.closeButton.titleLabel.font = [IBTheme mediumFontOfSize:15.0];
    [self.closeButton addTarget:self
                         action:@selector(closeTapped)
               forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.closeButton];

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.text = @"Modo lector";
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.font = [IBTheme boldFontOfSize:15.0];
    self.titleLabel.textColor = [IBTheme text];
    [self.topBar addSubview:self.titleLabel];

    self.shareButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.shareButton setTitle:@"Compartir" forState:UIControlStateNormal];
    [self.shareButton setTitleColor:[IBTheme accent] forState:UIControlStateNormal];
    self.shareButton.titleLabel.font = [IBTheme mediumFontOfSize:15.0];
    [self.shareButton addTarget:self
                         action:@selector(shareTapped)
               forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.shareButton];

    UIView *line = [[UIView alloc] initWithFrame:CGRectZero];
    line.backgroundColor = [IBTheme chromeBorder];
    line.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    line.tag = 701;
    [self.topBar addSubview:line];

    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    configuration.preferences.javaScriptEnabled = NO;
    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero
                                      configuration:configuration];
    self.webView.navigationDelegate = self;
    self.webView.backgroundColor = [IBTheme paper];
    self.webView.scrollView.backgroundColor = [IBTheme paper];
    self.webView.opaque = NO;
    [self.view addSubview:self.webView];

    [self loadArticle];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat top = self.topLayoutGuide.length;
    if (top <= 0.0) { top = 20.0; }
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    CGFloat barHeight = top + IBKReaderBarHeight;

    self.topBar.frame = CGRectMake(0, 0, width, barHeight);
    self.closeButton.frame = CGRectMake(10, top + 8, 74, 34);
    self.shareButton.frame = CGRectMake(width - 94, top + 8, 84, 34);
    self.titleLabel.frame = CGRectMake(96, top + 8, width - 192, 34);

    UIView *line = [self.topBar viewWithTag:701];
    line.frame = CGRectMake(0, barHeight - [IBTheme hairline],
                            width, [IBTheme hairline]);

    self.webView.frame = CGRectMake(0, barHeight, width, height - barHeight);
}

- (void)dealloc {
    self.webView.navigationDelegate = nil;
    [self.webView stopLoading];
}

#pragma mark - Contenido

- (NSString *)escapedText:(NSString *)text {
    if (![text isKindOfClass:[NSString class]]) { return @""; }
    NSMutableString *value = [text mutableCopy];
    [value replaceOccurrencesOfString:@"&" withString:@"&amp;"
                              options:0 range:NSMakeRange(0, value.length)];
    [value replaceOccurrencesOfString:@"<" withString:@"&lt;"
                              options:0 range:NSMakeRange(0, value.length)];
    [value replaceOccurrencesOfString:@">" withString:@"&gt;"
                              options:0 range:NSMakeRange(0, value.length)];
    [value replaceOccurrencesOfString:@"\"" withString:@"&quot;"
                              options:0 range:NSMakeRange(0, value.length)];
    return value;
}

- (NSString *)htmlFromArticle:(NSDictionary *)article {
    NSString *title = [self escapedText:article[@"title"]];
    NSString *author = [self escapedText:article[@"author"]];
    NSString *text = article[@"text"];
    if (![text isKindOfClass:[NSString class]]) { text = @""; }

    NSURL *url = [NSURL URLWithString:article[@"url"] ?: @""];
    NSString *host = [self escapedText:[IBURLNormalizer displayHostForURL:url]];

    NSMutableString *body = [NSMutableString string];
    NSArray *blocks = [text componentsSeparatedByString:@"\n\n"];
    for (NSString *block in blocks) {
        NSString *trimmed = [block stringByTrimmingCharactersInSet:
                             [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length == 0) { continue; }
        NSString *escaped = [self escapedText:trimmed];
        escaped = [escaped stringByReplacingOccurrencesOfString:@"\n"
                                                     withString:@"<br>"];
        [body appendFormat:@"<p>%@</p>\n", escaped];
    }

    if (body.length == 0) {
        [body appendString:@"<p>No se encontró texto legible en esta página.</p>"];
    }

    NSString *meta = host.length ? host : @"";
    if (author.length) {
        meta = meta.length
            ? [NSString stringWithFormat:@"%@ · %@", author, meta]
            : author;
    }

    return [NSString stringWithFormat:
        @"<!DOCTYPE html><html lang=\"es\"><head><meta charset=\"utf-8\">"
         "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
         "<style>"
         "html{-webkit-text-size-adjust:100%%;}"
         "body{margin:0;padding:34px 30px 64px;background:#fbf8f1;color:#1d2028;"
         "font-family:Georgia,'Times New Roman',serif;font-size:20px;line-height:1.62;}"
         ".wrap{max-width:680px;margin:0 auto;}"
         "h1{font-size:32px;line-height:1.18;margin:0 0 10px;letter-spacing:-.5px;}"
         ".meta{font-family:-apple-system,'Helvetica Neue',Arial,sans-serif;"
         "font-size:12px;letter-spacing:.4px;text-transform:uppercase;color:#8a8f9c;"
         "margin:0 0 22px;}"
         "hr{border:0;border-top:1px solid #e3ddcf;margin:0 0 28px;}"
         "p{margin:0 0 1.05em;}"
         "a{color:#1b68f2;}"
         "@media (max-width:600px){body{font-size:18px;padding:24px 18px 48px;}"
         "h1{font-size:25px;}}"
         "</style></head><body><div class=\"wrap\">"
         "<h1>%@</h1><p class=\"meta\">%@</p><hr>%@"
         "</div></body></html>",
        title.length ? title : @"Sin título",
        meta,
        body];
}

- (void)loadArticle {
    NSString *html = [self htmlFromArticle:self.article];
    [self.webView loadHTMLString:html
                         baseURL:[NSURL URLWithString:@"about:blank"]];
}

#pragma mark - Acciones

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)shareTapped {
    NSString *title = self.article[@"title"] ?: @"Artículo";
    NSURL *url = [NSURL URLWithString:self.article[@"url"] ?: @""];
    NSMutableArray *items = [NSMutableArray arrayWithObject:title];
    if (url) { [items addObject:url]; }

    UIActivityViewController *activity = [[UIActivityViewController alloc]
        initWithActivityItems:items
        applicationActivities:nil];
    if (activity.popoverPresentationController) {
        activity.popoverPresentationController.sourceView = self.shareButton;
        activity.popoverPresentationController.sourceRect = self.shareButton.bounds;
        activity.popoverPresentationController.permittedArrowDirections =
            UIPopoverArrowDirectionUp;
    }
    [self presentViewController:activity animated:YES completion:nil];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;
    NSString *scheme = [url.scheme lowercaseString];

    if (navigationAction.navigationType == WKNavigationTypeLinkActivated &&
        ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"])) {
        decisionHandler(WKNavigationActionPolicyCancel);
        if (self.onOpenURL) { self.onOpenURL(url); }
        return;
    }

    if (navigationAction.navigationType == WKNavigationTypeLinkActivated &&
        ![scheme isEqualToString:@"about"] && ![scheme isEqualToString:@"file"]) {
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }

    decisionHandler(WKNavigationActionPolicyAllow);
}

@end
