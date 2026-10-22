#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@class IBWebTab;

@protocol IBWebTabDelegate <NSObject>
@optional
- (void)webTabDidStartLoading:(IBWebTab *)tab;
- (void)webTabDidFinishLoading:(IBWebTab *)tab;
- (void)webTab:(IBWebTab *)tab didFailWithError:(NSError *)error;
- (void)webTabDidUpdateTitle:(IBWebTab *)tab;
- (void)webTabDidUpdateURL:(IBWebTab *)tab;
- (void)webTabDidUpdateProgress:(IBWebTab *)tab;
- (void)webTab:(IBWebTab *)tab requestOpenURLInNewTab:(NSURL *)url;
- (void)webTab:(IBWebTab *)tab requestOpenExternalURL:(NSURL *)url;
- (void)webTab:(IBWebTab *)tab requestDownloadURL:(NSURL *)url suggestedName:(NSString *)name;
- (void)webTab:(IBWebTab *)tab requestSearch:(NSString *)query;
- (void)webTabDidRequestFocusAddress:(IBWebTab *)tab;
@end

@interface IBWebTab : NSObject

@property (nonatomic, weak) id<IBWebTabDelegate> delegate;
@property (nonatomic, weak) UIViewController *presentingViewController;

@property (nonatomic, strong, readonly) WKWebView *webView;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong, readonly) NSURL *currentURL;
@property (nonatomic, strong, readonly) NSURL *requestedURL;
@property (nonatomic, assign, readonly) BOOL isStartPage;
@property (nonatomic, assign, readonly) BOOL loading;
@property (nonatomic, assign, readonly) double progress;

- (instancetype)initWithDelegate:(id<IBWebTabDelegate>)delegate;

- (void)loadURL:(NSURL *)url;
- (void)loadStartPage;
- (void)reload;
- (void)stopLoading;
- (void)goBack;
- (void)goForward;
- (BOOL)canGoBack;
- (BOOL)canGoForward;

- (void)refreshUserScripts;
- (void)unload;
- (void)restoreIfNeeded;

- (void)evaluateReaderWithCompletion:(void (^)(NSDictionary *result))completion;

@end
