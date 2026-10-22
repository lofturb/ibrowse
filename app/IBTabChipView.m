#import "IBTabChipView.h"
#import "IBTheme.h"

@interface IBTabChipView ()
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UIButton *closeButton;
@end

@implementation IBTabChipView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.layer.cornerRadius = 7.0;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOffset = CGSizeMake(0, 1);
        self.layer.shadowRadius = 2.0;
        self.layer.shadowOpacity = 0.0;

        _label = [[UILabel alloc] initWithFrame:CGRectZero];
        _label.font = [IBTheme mediumFontOfSize:12.5];
        _label.textColor = [IBTheme secondaryText];
        _label.lineBreakMode = NSLineBreakByTruncatingTail;
        _label.backgroundColor = [UIColor clearColor];
        [self addSubview:_label];

        _closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_closeButton setTitle:@"\u00D7" forState:UIControlStateNormal];
        [_closeButton setTitleColor:[IBTheme tertiaryText] forState:UIControlStateNormal];
        _closeButton.titleLabel.font = [IBTheme fontOfSize:17.0];
        _closeButton.accessibilityLabel = @"Cerrar pestaña";
        [_closeButton addTarget:self
                         action:@selector(closeTapped)
               forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_closeButton];

        UITapGestureRecognizer *tap =
            [[UITapGestureRecognizer alloc] initWithTarget:self
                                                    action:@selector(tapped)];
        [self addGestureRecognizer:tap];

        self.isAccessibilityElement = YES;
        self.accessibilityTraits = UIAccessibilityTraitButton;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat closeSize = 24.0;
    CGFloat labelLeft = 10.0;
    self.closeButton.frame = CGRectMake(self.bounds.size.width - closeSize - 4.0,
                                        (self.bounds.size.height - closeSize) / 2.0,
                                        closeSize, closeSize);
    self.label.frame = CGRectMake(labelLeft, 0,
                                  self.bounds.size.width - labelLeft - closeSize - 8.0,
                                  self.bounds.size.height);
}

- (void)setTitle:(NSString *)title {
    _title = [title copy];
    self.label.text = _title;
    self.accessibilityLabel = _title;
    [self setNeedsLayout];
}

- (void)setSelected:(BOOL)selected {
    _selected = selected;
    if (selected) {
        self.backgroundColor = [IBTheme selectedTab];
        self.label.textColor = [IBTheme text];
        self.closeButton.hidden = NO;
        self.layer.shadowOpacity = 0.10;
    } else {
        self.backgroundColor = [UIColor clearColor];
        self.label.textColor = [IBTheme secondaryText];
        self.closeButton.hidden = YES;
        self.layer.shadowOpacity = 0.0;
    }
    [self setNeedsLayout];
}

- (void)setLoading:(BOOL)loading {
    _loading = loading;
    if (loading) {
        self.label.textColor = _selected ? [IBTheme accent] : [IBTheme secondaryText];
    } else {
        self.label.textColor = _selected ? [IBTheme text] : [IBTheme secondaryText];
    }
}

- (CGFloat)preferredWidth {
    CGFloat width = [self.label sizeThatFits:CGSizeMake(1000, 20)].width;
    CGFloat total = width + 10.0 + 24.0 + 10.0;
    return MAX(76.0, MIN(176.0, total));
}

- (void)tapped {
    if (self.onSelect) { self.onSelect(); }
}

- (void)closeTapped {
    if (self.onClose) { self.onClose(); }
}

@end
