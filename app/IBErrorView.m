#import "IBErrorView.h"
#import "IBTheme.h"

@interface IBErrorView ()
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UILabel *iconLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIButton *retryButton;
@property (nonatomic, strong) UIButton *safariButton;
@end

@implementation IBErrorView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.96];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                UIViewAutoresizingFlexibleHeight;

        _card = [[UIView alloc] initWithFrame:CGRectZero];
        _card.backgroundColor = [UIColor whiteColor];
        _card.layer.cornerRadius = 16.0;
        _card.layer.shadowColor = [UIColor blackColor].CGColor;
        _card.layer.shadowOpacity = 0.10;
        _card.layer.shadowRadius = 18.0;
        _card.layer.shadowOffset = CGSizeMake(0, 8);
        [self addSubview:_card];

        _iconLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _iconLabel.text = @"!";
        _iconLabel.textAlignment = NSTextAlignmentCenter;
        _iconLabel.font = [IBTheme boldFontOfSize:30.0];
        _iconLabel.textColor = [IBTheme danger];
        _iconLabel.backgroundColor = [UIColor colorWithRed:1.0 green:0.94 blue:0.94 alpha:1.0];
        _iconLabel.layer.cornerRadius = 28.0;
        _iconLabel.clipsToBounds = YES;
        [_card addSubview:_iconLabel];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.font = [IBTheme boldFontOfSize:21.0];
        _titleLabel.textColor = [IBTheme text];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.numberOfLines = 2;
        [_card addSubview:_titleLabel];

        _messageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _messageLabel.font = [IBTheme fontOfSize:14.0];
        _messageLabel.textColor = [IBTheme secondaryText];
        _messageLabel.textAlignment = NSTextAlignmentCenter;
        _messageLabel.numberOfLines = 0;
        [_card addSubview:_messageLabel];

        _retryButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_retryButton setTitle:@"Reintentar" forState:UIControlStateNormal];
        [_retryButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _retryButton.titleLabel.font = [IBTheme mediumFontOfSize:15.0];
        _retryButton.backgroundColor = [IBTheme accent];
        _retryButton.layer.cornerRadius = 10.0;
        [_retryButton addTarget:self
                         action:@selector(retryTapped)
               forControlEvents:UIControlEventTouchUpInside];
        [_card addSubview:_retryButton];

        _safariButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_safariButton setTitle:@"Abrir en Safari" forState:UIControlStateNormal];
        [_safariButton setTitleColor:[IBTheme secondaryText] forState:UIControlStateNormal];
        _safariButton.titleLabel.font = [IBTheme fontOfSize:14.0];
        [_safariButton addTarget:self
                          action:@selector(safariTapped)
                forControlEvents:UIControlEventTouchUpInside];
        [_card addSubview:_safariButton];

        self.hidden = YES;
    }
    return self;
}

- (void)showWithTitle:(NSString *)title message:(NSString *)message {
    self.titleLabel.text = title;
    self.messageLabel.text = message;
    self.hidden = NO;
    [self setNeedsLayout];
}

- (void)hide {
    self.hidden = YES;
}

- (void)retryTapped {
    if (self.onRetry) { self.onRetry(); }
}

- (void)safariTapped {
    if (self.onOpenSafari) { self.onOpenSafari(); }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat availableWidth = self.bounds.size.width - 48.0;
    CGFloat cardWidth = MIN(520.0, MAX(300.0, availableWidth));
    CGFloat innerWidth = cardWidth - 52.0;

    CGSize titleSize = [self.titleLabel sizeThatFits:CGSizeMake(innerWidth, 80)];
    CGSize messageSize = [self.messageLabel sizeThatFits:CGSizeMake(innerWidth, 240)];

    CGFloat height = 28.0 + 56.0 + 14.0 + titleSize.height + 8.0 +
                     messageSize.height + 22.0 + 42.0 + 8.0 + 30.0 + 24.0;
    CGFloat cardX = (self.bounds.size.width - cardWidth) / 2.0;
    CGFloat cardY = MAX(20.0, (self.bounds.size.height - height) / 2.0 - 20.0);

    self.card.frame = CGRectMake(cardX, cardY, cardWidth, height);
    CGFloat x = 26.0;
    self.iconLabel.frame = CGRectMake((cardWidth - 56.0) / 2.0, 28.0, 56.0, 56.0);
    self.titleLabel.frame = CGRectMake(x, 98.0, innerWidth, titleSize.height);
    self.messageLabel.frame = CGRectMake(x, CGRectGetMaxY(self.titleLabel.frame) + 8.0,
                                         innerWidth, messageSize.height);
    self.retryButton.frame = CGRectMake(x, CGRectGetMaxY(self.messageLabel.frame) + 22.0,
                                        innerWidth, 42.0);
    self.safariButton.frame = CGRectMake(x, CGRectGetMaxY(self.retryButton.frame) + 8.0,
                                         innerWidth, 30.0);
}

@end
