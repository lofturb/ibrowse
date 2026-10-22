#import "IBAboutViewController.h"
#import "IBTheme.h"

@interface IBAboutViewController ()

@property (nonatomic, strong) UITextView *textView;

@end

@implementation IBAboutViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Acerca de";
    self.view.backgroundColor = [UIColor whiteColor];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                             target:self
                             action:@selector(doneTapped)];

    self.textView = [[UITextView alloc] initWithFrame:CGRectZero];
    self.textView.editable = NO;
    self.textView.scrollEnabled = YES;
    self.textView.backgroundColor = [UIColor whiteColor];
    self.textView.textContainerInset = UIEdgeInsetsMake(20, 20, 30, 20);
    self.textView.dataDetectorTypes = UIDataDetectorTypeLink;
    self.textView.linkTextAttributes = @{
        NSForegroundColorAttributeName: [IBTheme accent],
        NSUnderlineStyleAttributeName: @(NSUnderlineStyleNone)
    };
    self.textView.attributedText = [self aboutText];
    [self.view addSubview:self.textView];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat top = self.topLayoutGuide.length;
    self.textView.frame = CGRectMake(0, top, self.view.bounds.size.width,
                                     self.view.bounds.size.height - top);
}

- (void)doneTapped {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)appendText:(NSString *)text
              font:(UIFont *)font
             color:(UIColor *)color
           spacing:(CGFloat)spacing
                to:(NSMutableAttributedString *)result {
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.paragraphSpacing = spacing;
    style.lineHeightMultiple = 1.04;
    NSAttributedString *chunk = [[NSAttributedString alloc]
        initWithString:text
            attributes:@{
                NSFontAttributeName: font,
                NSForegroundColorAttributeName: color,
                NSParagraphStyleAttributeName: style
            }];
    [result appendAttributedString:chunk];
}

- (NSAttributedString *)aboutText {
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] init];

    [self appendText:@"IBrowse\n"
                font:[IBTheme boldFontOfSize:30.0]
               color:[IBTheme text]
             spacing:2.0
                  to:text];
    [self appendText:[NSString stringWithFormat:@"Versión %@ · WebKit iOS 9 · armv7\n\n",
                      [IBTheme appVersion]]
                font:[IBTheme fontOfSize:12.5]
               color:[IBTheme tertiaryText]
             spacing:14.0
                  to:text];

    [self appendText:@"Un navegador para el iPad mini 1\n"
                font:[IBTheme boldFontOfSize:15.0]
               color:[IBTheme text]
             spacing:5.0
                  to:text];
    [self appendText:@"Nació de una idea sencilla: que un iPad de 2012 con iOS 9.3.6 "
                     "siga sirviendo para leer, buscar y navegar sin depender de otro "
                     "dispositivo. No sustituye a WebKit —eso es imposible—, pero intenta "
                     "que las webs modernas fallen menos y se entiendan mejor.\n\n"
                font:[IBTheme fontOfSize:14.0]
               color:[IBTheme secondaryText]
             spacing:14.0
                  to:text];

    [self appendText:@"Qué incluye\n"
                font:[IBTheme boldFontOfSize:15.0]
               color:[IBTheme text]
             spacing:5.0
                  to:text];
    [self appendText:@"· Pestañas con sesión restaurable y modo privado.\n"
                     "· Historial, marcadores y descargas persistentes.\n"
                     "· Bloqueo de anuncios y rastreadores por listas.\n"
                     "· Polyfills ES5 para APIs modernas (Promise, fetch parcial, "
                     "IntersectionObserver, matchMedia…).\n"
                     "· Modo lector que extrae el texto del artículo.\n"
                     "· Modo Relay opcional: un servidor Node en tu red local transpila "
                     "JavaScript moderno y reescribe HTML/CSS antes de enviarlo al iPad.\n"
                     "· Intercepción de descargas y guardado en /var/mobile/Media.\n\n"
                font:[IBTheme fontOfSize:14.0]
               color:[IBTheme secondaryText]
             spacing:14.0
                  to:text];

    [self appendText:@"Límites honestos\n"
                font:[IBTheme boldFontOfSize:15.0]
               color:[IBTheme text]
             spacing:5.0
                  to:text];
    [self appendText:@"iOS 9 trae el WebKit de 2015. Ningún navegador de la App Store "
                     "puede cambiar eso, y compilar un motor nuevo para armv7 no es viable. "
                     "IBrowse reduce los fallos con polyfills y, si lo activas, con el relay. "
                     "Aun así habrá webs que no funcionen: vídeo moderno, WebGL pesado, "
                     "WebAssembly o cifrados TLS que iOS 9 ya no negocia.\n\n"
                     "El Modo Relay ve el tráfico que pasa por él. Úsalo solo en una red "
                     "de confianza y nunca con banca o contraseñas si no controlas el servidor.\n\n"
                font:[IBTheme fontOfSize:14.0]
               color:[IBTheme secondaryText]
             spacing:14.0
                  to:text];

    [self appendText:@"Privacidad\n"
                font:[IBTheme boldFontOfSize:15.0]
               color:[IBTheme text]
             spacing:5.0
                  to:text];
    [self appendText:@"IBrowse no incluye telemetría ni cuentas. El historial, los "
                     "marcadores y las descargas se quedan en el iPad. El relay es tu propio "
                     "servidor y solo se usa si lo activas expresamente.\n\n"
                font:[IBTheme fontOfSize:14.0]
               color:[IBTheme secondaryText]
             spacing:14.0
                  to:text];

    [self appendText:@"Créditos y licencia\n"
                font:[IBTheme boldFontOfSize:15.0]
               color:[IBTheme text]
             spacing:5.0
                  to:text];
    [self appendText:@"Compilado con Theos, el toolchain LLVM de L1ghtmann, el SDK "
                     "iPhoneOS9.3 y ldid. La estructura de compilación sigue la guía "
                     "Guia-IPA-iOS9. Código bajo licencia MIT; WebKit es propiedad de Apple.\n\n"
                     "Proyecto personal, sin afiliación con Apple, Brave ni DuckDuckGo.\n"
                font:[IBTheme fontOfSize:14.0]
               color:[IBTheme secondaryText]
             spacing:8.0
                  to:text];

    [self appendText:@"https://github.com/lofturb/ibrowse"
                font:[IBTheme fontOfSize:13.0]
               color:[IBTheme accent]
             spacing:0.0
                  to:text];

    return text;
}

@end
