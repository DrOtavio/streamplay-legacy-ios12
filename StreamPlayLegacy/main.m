#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <WebKit/WebKit.h>
#import <MobileCoreServices/MobileCoreServices.h>

static UIColor *SPLBackground(void) { return [UIColor colorWithRed:0.030 green:0.048 blue:0.042 alpha:1]; }
static UIColor *SPLPanel(void) { return [UIColor colorWithRed:0.087 green:0.119 blue:0.101 alpha:1]; }
static UIColor *SPLAccent(void) { return [UIColor colorWithRed:0.83 green:1.0 blue:0.40 alpha:1]; }
static UIColor *SPLMuted(void) { return [UIColor colorWithWhite:0.66 alpha:1]; }
static NSString * const SPLChannelsKey = @"SPLLegacy.channels.v1";
static NSString * const SPLSourcesKey = @"SPLLegacy.sources.v1";

@interface SPLLibrary : NSObject
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *channels;
@property (nonatomic, strong) NSMutableArray<NSString *> *sources;
+ (instancetype)shared;
- (void)save;
- (void)loadPlaylistURL:(NSString *)urlText completion:(void (^)(NSString *message, BOOL success))completion;
- (void)loadPlaylistData:(NSData *)data label:(NSString *)label completion:(void (^)(NSString *message, BOOL success))completion;
@end

@implementation SPLLibrary
+ (instancetype)shared { static SPLLibrary *s; static dispatch_once_t once; dispatch_once(&once, ^{ s = [SPLLibrary new]; }); return s; }
- (instancetype)init {
    if ((self = [super init])) {
        NSArray *old = [[NSUserDefaults standardUserDefaults] arrayForKey:SPLChannelsKey];
        _channels = old ? [old mutableCopy] : [NSMutableArray array];
        NSArray *src = [[NSUserDefaults standardUserDefaults] arrayForKey:SPLSourcesKey];
        _sources = src ? [src mutableCopy] : [NSMutableArray array];
    }
    return self;
}
- (void)save {
    [[NSUserDefaults standardUserDefaults] setObject:self.channels forKey:SPLChannelsKey];
    [[NSUserDefaults standardUserDefaults] setObject:self.sources forKey:SPLSourcesKey];
}
- (void)loadPlaylistURL:(NSString *)urlText completion:(void (^)(NSString *, BOOL))completion {
    NSString *trim = [urlText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSURL *url = [NSURL URLWithString:trim];
    if (!url || !([url.scheme.lowercaseString isEqualToString:@"https"] || [url.scheme.lowercaseString isEqualToString:@"http"])) {
        completion(@"Use um endereço HTTP ou HTTPS válido.", NO); return;
    }
    // HLS manifests are playable as streams, not collections of channels.
    NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    config.timeoutIntervalForRequest = 25;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    [[session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !data) { completion(error.localizedDescription ?: @"Não foi possível obter a lista.", NO); return; }
            if (data.length > 8 * 1024 * 1024) { completion(@"A lista excede 8 MB. Importe uma lista menor.", NO); return; }
            if ([response isKindOfClass:NSHTTPURLResponse.class] && ((NSHTTPURLResponse *)response).statusCode >= 400) {
                completion([NSString stringWithFormat:@"Servidor HTTP %ld", (long)((NSHTTPURLResponse *)response).statusCode], NO); return;
            }
            [self loadPlaylistData:data label:trim completion:completion];
        });
        [session finishTasksAndInvalidate];
    }] resume];
}
- (void)loadPlaylistData:(NSData *)data label:(NSString *)label completion:(void (^)(NSString *, BOOL))completion {
    if (data.length > 8 * 1024 * 1024) { completion(@"Arquivo acima de 8 MB.", NO); return; }
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!text) text = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    if (!text) { completion(@"Não foi possível interpretar o arquivo M3U.", NO); return; }
    if ([text containsString:@"#EXT-X-STREAM-INF"] || [text containsString:@"#EXT-X-TARGETDURATION"]) {
        completion(@"Este link parece uma transmissão HLS, e não uma lista de canais. Utilize uma playlist M3U com #EXTINF.", NO); return;
    }
    NSArray<NSString *> *lines = [text componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet];
    NSMutableArray *parsed = [NSMutableArray array];
    NSString *title = nil; NSString *group = @"Canais";
    NSRegularExpression *groupRegex = [NSRegularExpression regularExpressionWithPattern:@"group-title=\\\"([^\\\"]*)\\\"" options:NSRegularExpressionCaseInsensitive error:nil];
    for (NSString *sourceLine in lines) {
        NSString *line = [sourceLine stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if ([line hasPrefix:@"#EXTINF:"]) {
            NSRange comma = [line rangeOfString:@"," options:NSBackwardsSearch];
            title = comma.location != NSNotFound ? [line substringFromIndex:comma.location + 1] : @"Canal sem nome";
            NSTextCheckingResult *match = [groupRegex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
            group = match ? [line substringWithRange:[match rangeAtIndex:1]] : @"Canais";
        } else if (title && line.length && ![line hasPrefix:@"#"]) {
            NSURL *stream = [NSURL URLWithString:line];
            if (stream && ([stream.scheme.lowercaseString isEqualToString:@"http"] || [stream.scheme.lowercaseString isEqualToString:@"https"])) {
                [parsed addObject:@{@"name": title.length ? title : @"Canal", @"url": line, @"group":group.length ? group : @"Canais"}];
            }
            title = nil;
            if (parsed.count >= 15000) break;
        }
    }
    if (!parsed.count) { completion(@"Nenhum canal HTTP/HTTPS encontrado. Verifique o formato M3U.", NO); return; }
    // Replace channels imported from the same source; other lists remain intact.
    NSMutableArray *incoming = [NSMutableArray arrayWithCapacity:parsed.count];
    for (NSDictionary *entry in parsed) {
        NSMutableDictionary *item = [entry mutableCopy];
        item[@"source"] = label ?: @"Importado";
        [incoming addObject:item];
    }
    NSIndexSet *old = [self.channels indexesOfObjectsPassingTest:^BOOL(NSDictionary *entry, NSUInteger idx, BOOL *stop) {
        return [entry[@"source"] isEqualToString:label];
    }];
    [self.channels removeObjectsAtIndexes:old];
    [self.channels addObjectsFromArray:incoming];
    if (label.length && ![self.sources containsObject:label]) [self.sources addObject:label];
    [self save];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SPLChannelsUpdated" object:nil];
    completion([NSString stringWithFormat:@"%lu canais importados.", (unsigned long)incoming.count], YES);
}
@end

@interface SPLPlayerController : UIViewController
- (instancetype)initWithChannel:(NSDictionary *)channel;
@end
@implementation SPLPlayerController {
    NSDictionary *_channel;
    AVPlayer *_player;
    AVPlayerLayer *_layer;
    UILabel *_info;
    UIButton *_toggle;
    BOOL _paused;
}
- (instancetype)initWithChannel:(NSDictionary *)channel { if ((self = [super init])) _channel = [channel copy]; return self; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = SPLBackground();
    self.title = _channel[@"name"];
    _layer = [AVPlayerLayer playerLayerWithPlayer:nil];
    _layer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.view.layer addSublayer:_layer];
    _info = [UILabel new]; _info.numberOfLines = 4; _info.textColor = UIColor.whiteColor;
    _info.textAlignment = NSTextAlignmentCenter; _info.font = [UIFont systemFontOfSize:15];
    _info.text = [NSString stringWithFormat:@"%@\n%@", _channel[@"name"], _channel[@"group"] ?: @""];
    [self.view addSubview:_info];
    _toggle = [UIButton buttonWithType:UIButtonTypeSystem];
    [_toggle setTitle:@"Pausar" forState:UIControlStateNormal]; [_toggle setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    _toggle.backgroundColor = SPLAccent(); _toggle.layer.cornerRadius = 12; _toggle.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [_toggle addTarget:self action:@selector(toggle) forControlEvents:UIControlEventTouchUpInside]; [self.view addSubview:_toggle];
    NSURL *url = [NSURL URLWithString:_channel[@"url"] ?: @""];
    if (url) {
        NSError *audioError = nil;
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&audioError];
        [[AVAudioSession sharedInstance] setActive:YES error:&audioError];
        _player = [AVPlayer playerWithURL:url]; _player.allowsExternalPlayback = YES;
        _layer.player = _player;
        if (audioError) NSLog(@"StreamPlay Legacy audio: %@", audioError);
        [_player play];
    }
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat width = self.view.bounds.size.width;
    CGFloat top = self.topLayoutGuide.length + 8;
    _layer.frame = CGRectMake(0, top, width, MIN(width * 0.56, self.view.bounds.size.height * 0.58));
    _info.frame = CGRectMake(15, CGRectGetMaxY(_layer.frame) + 18, width - 30, 75);
    _toggle.frame = CGRectMake(35, CGRectGetMaxY(_info.frame) + 14, width - 70, 48);
}
- (void)toggle {
    _paused = !_paused;
    if (_paused) [_player pause]; else [_player play];
    [_toggle setTitle:_paused ? @"Reproduzir" : @"Pausar" forState:UIControlStateNormal];
}
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [_player pause]; }
@end

@interface SPLChannelsController : UITableViewController <UISearchResultsUpdating, UIDocumentPickerDelegate>
@end
@implementation SPLChannelsController {
    UISearchController *_search;
    NSArray<NSDictionary *> *_visible;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"Canais"; self.tableView.backgroundColor = SPLBackground();
    self.tableView.rowHeight = 64;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addSource)];
    _search = [[UISearchController alloc] initWithSearchResultsController:nil];
    _search.searchResultsUpdater = self; _search.dimsBackgroundDuringPresentation = NO;
    _search.searchBar.placeholder = @"Buscar canal";
    _search.searchBar.frame = CGRectMake(0, 0, 320, 56); self.tableView.tableHeaderView = _search.searchBar; self.definesPresentationContext = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadChannels) name:@"SPLChannelsUpdated" object:nil];
    [self reloadChannels];
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)updateSearchResultsForSearchController:(UISearchController *)searchController { [self reloadChannels]; }
- (void)reloadChannels {
    NSString *term = _search.searchBar.text ?: @"";
    if (!term.length) _visible = [[SPLLibrary shared].channels copy];
    else _visible = [[SPLLibrary shared].channels filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *e, NSDictionary *bindings) {
        return [e[@"name"] localizedCaseInsensitiveContainsString:term] || [e[@"group"] localizedCaseInsensitiveContainsString:term];
    }]];
    [self.tableView reloadData];
    if (!_visible.count) {
        UILabel *empty = [UILabel new]; empty.numberOfLines = 0; empty.textAlignment = NSTextAlignmentCenter;
        empty.textColor = SPLMuted(); empty.font = [UIFont systemFontOfSize:16];
        empty.text = @"Nenhum canal importado.\nToque em + para carregar uma lista M3U.\n\nO app também pode ser aberto pelo CarBridge Legacy.";
        self.tableView.backgroundView = empty;
    } else self.tableView.backgroundView = nil;
}
- (void)addSource {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Adicionar canais" message:@"Importe uma lista M3U ou teste o player." preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Importar URL M3U" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ [self inputURL]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Importar arquivo M3U" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ [self openFile]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Adicionar vídeo de demonstração" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *demo = @"https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8";
        NSMutableArray *arr = [SPLLibrary shared].channels;
        [arr addObject:@{@"name":@"Vídeo de teste (HLS)", @"group":@"Demonstração", @"url":demo, @"source":@"Teste"}];
        [[SPLLibrary shared] save]; [self reloadChannels];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    [self presentViewController:sheet animated:YES completion:nil];
}
- (void)inputURL {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Importar lista M3U" message:@"URL HTTP/HTTPS da playlist" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *t) { t.placeholder = @"https://servidor/lista.m3u"; t.keyboardType = UIKeyboardTypeURL; t.autocapitalizationType = UITextAutocapitalizationTypeNone; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Importar" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *url = alert.textFields.firstObject.text ?: @"";
        [[SPLLibrary shared] loadPlaylistURL:url completion:^(NSString *message, BOOL success) { [self report:message]; }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)openFile {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[(NSString *)kUTTypePlainText, @"public.data"] inMode:UIDocumentPickerModeImport];
    picker.delegate = self; [self presentViewController:picker animated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url {
    NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:nil];
    if (!data) { [self report:@"Falha ao abrir o arquivo M3U."]; return; }
    [[SPLLibrary shared] loadPlaylistData:data label:url.lastPathComponent completion:^(NSString *message, BOOL success) { [self report:message]; }];
}
- (void)report:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"StreamPlay" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return _visible.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"channel"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"channel"];
    NSDictionary *entry = _visible[indexPath.row]; cell.textLabel.text = entry[@"name"];
    cell.detailTextLabel.text = entry[@"group"]; cell.textLabel.textColor = UIColor.whiteColor; cell.detailTextLabel.textColor = SPLMuted();
    cell.backgroundColor = SPLPanel(); cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.navigationController pushViewController:[[SPLPlayerController alloc] initWithChannel:_visible[indexPath.row]] animated:YES];
}
@end

@interface SPLBrowserController : UIViewController <WKNavigationDelegate, UITextFieldDelegate>
@end
@implementation SPLBrowserController {
    WKWebView *_web;
    UITextField *_address;
    UIToolbar *_toolbar;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"Navegador"; self.view.backgroundColor = SPLBackground();
    self.edgesForExtendedLayout = UIRectEdgeNone;
    WKWebViewConfiguration *config = [WKWebViewConfiguration new]; config.allowsInlineMediaPlayback = YES;
    config.allowsAirPlayForMediaPlayback = YES;
    _web = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    _web.navigationDelegate = self; _web.opaque = NO; _web.backgroundColor = SPLBackground();
    _address = [[UITextField alloc] initWithFrame:CGRectZero]; _address.borderStyle = UITextBorderStyleRoundedRect;
    _address.backgroundColor = UIColor.whiteColor; _address.textColor = UIColor.blackColor;
    _address.placeholder = @"https://... ou texto para pesquisar"; _address.keyboardType = UIKeyboardTypeURL;
    _address.autocapitalizationType = UITextAutocapitalizationTypeNone; _address.autocorrectionType = UITextAutocorrectionTypeNo;
    _address.delegate = self; _address.returnKeyType = UIReturnKeyGo;
    _toolbar = [UIToolbar new]; _toolbar.barTintColor = SPLPanel();
    UIBarButtonItem *back = [[UIBarButtonItem alloc] initWithTitle:@"◀" style:UIBarButtonItemStylePlain target:self action:@selector(back)];
    UIBarButtonItem *forward = [[UIBarButtonItem alloc] initWithTitle:@"▶" style:UIBarButtonItemStylePlain target:self action:@selector(forward)];
    UIBarButtonItem *reload = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reload)];
    UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    _toolbar.items = @[back, space, forward, space, reload];
    [self.view addSubview:_address]; [self.view addSubview:_web]; [self.view addSubview:_toolbar];
    _address.text = @"https://www.google.com"; [self go];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat top = self.topLayoutGuide.length; CGFloat bottom = self.bottomLayoutGuide.length;
    CGFloat w = self.view.bounds.size.width; CGFloat h = self.view.bounds.size.height;
    _address.frame = CGRectMake(10, top + 8, w - 20, 38);
    _toolbar.frame = CGRectMake(0, h - bottom - 44, w, 44);
    _web.frame = CGRectMake(0, CGRectGetMaxY(_address.frame) + 5, w, MAX(0, CGRectGetMinY(_toolbar.frame) - CGRectGetMaxY(_address.frame) - 5));
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField { [self go]; return YES; }
- (void)go {
    NSString *s = [_address.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!s.length) return;
    if (![s containsString:@"://"]) {
        if ([s containsString:@" "] || ![s containsString:@"."]) {
            NSString *q = [s stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet] ?: @"";
            s = [@"https://www.google.com/search?q=" stringByAppendingString:q];
        } else s = [@"https://" stringByAppendingString:s];
    }
    NSURL *url = [NSURL URLWithString:s];
    if (url && ([url.scheme.lowercaseString isEqualToString:@"http"] || [url.scheme.lowercaseString isEqualToString:@"https"])) {
        [_web loadRequest:[NSURLRequest requestWithURL:url]];
        [_address resignFirstResponder];
    }
}
- (void)back { if (_web.canGoBack) [_web goBack]; }
- (void)forward { if (_web.canGoForward) [_web goForward]; }
- (void)reload { [_web reload]; }
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation { _address.text = webView.URL.absoluteString; }
@end

@interface SPLSettingsController : UIViewController
@end
@implementation SPLSettingsController
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"CarPlay"; self.view.backgroundColor = SPLBackground();
    UITextView *text = [UITextView new]; text.editable = NO; text.scrollEnabled = YES;
    text.backgroundColor = SPLBackground(); text.textColor = UIColor.whiteColor;
    text.font = [UIFont systemFontOfSize:17];
    text.text = @"STREAMPLAY LEGACY 1.0\n\niOS 12.0+ • iPhone 6 / 6 Plus\n\nCOMO EXIBIR NO CARPLAY\n\n1. Instale o IPA com AppSync Unified + Filza.\n\n2. Confirme que o app abre normalmente no iPhone.\n\n3. Abra Ajustes > CarBridge Legacy e habilite StreamPlay Legacy em Bridged Applications (se disponível).\n\n4. Conecte ao CarPlay e procure o ícone. Se não abrir, teste Portal no CarBridge.\n\nO CarBridge é responsável pelo espelhamento/registro; este IPA não solicita entitlements oficiais CarPlay.\n\nUse vídeo e navegador somente quando estacionado ou em tela dedicada a passageiros.\n\nNOTAS\n\n• Suporte oficial do CarBridge Legacy termina no iOS 12.5.7; iOS 12.5.8 exige teste.\n\n• O navegador usa o WebKit do iOS 12 e pode falhar em sites modernos.\n\n• AVPlayer aceita HLS e MP4 compatíveis; UDP/RTSP e codecs desconhecidos não são convertidos.\n\n• URLs M3U são salvas localmente; não compartilhe playlists privadas.\n";
    [self.view addSubview:text]; text.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [text.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [text.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [text.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:8],
        [text.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-8]
    ]];
}
@end

// iOS 12: avoid UITabBarSystemItemFavorites, which can override the tab title.
// Simple template icons keep the three tabs readable on 4.7/5.5-inch screens.
static UIImage *SPLTabIcon(NSUInteger kind) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(26, 26), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(ctx, UIColor.blackColor.CGColor);
    CGContextSetFillColorWithColor(ctx, UIColor.blackColor.CGColor);
    CGContextSetLineWidth(ctx, 1.8);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    if (kind == 0) { // Canais: TV + play
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(2, 5, 22, 16) cornerRadius:3] stroke];
        UIBezierPath *play = [UIBezierPath bezierPath];
        [play moveToPoint:CGPointMake(10, 9)];
        [play addLineToPoint:CGPointMake(10, 17)];
        [play addLineToPoint:CGPointMake(17, 13)];
        [play closePath];
        [play fill];
    } else if (kind == 1) { // Navegador: globe
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(3, 3, 20, 20)] stroke];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(9, 3, 8, 20)] stroke];
        CGContextMoveToPoint(ctx, 3, 13);
        CGContextAddLineToPoint(ctx, 23, 13);
        CGContextStrokePath(ctx);
    } else { // CarPlay: car silhouette
        UIBezierPath *car = [UIBezierPath bezierPath];
        [car moveToPoint:CGPointMake(3, 11)];
        [car addLineToPoint:CGPointMake(7, 6)];
        [car addLineToPoint:CGPointMake(19, 6)];
        [car addLineToPoint:CGPointMake(23, 11)];
        [car addLineToPoint:CGPointMake(23, 19)];
        [car addLineToPoint:CGPointMake(3, 19)];
        [car closePath];
        [car stroke];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(6, 17, 4, 5)] fill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(16, 17, 4, 5)] fill];
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

@interface SPLAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation SPLAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIViewController *(^tab)(UIViewController *, NSString *, NSUInteger) = ^UIViewController *(UIViewController *vc, NSString *name, NSUInteger iconKind) {
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        nav.tabBarItem = [[UITabBarItem alloc] initWithTitle:name image:SPLTabIcon(iconKind) tag:iconKind];
        nav.navigationBar.barTintColor = SPLPanel(); nav.navigationBar.tintColor = SPLAccent();
        nav.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor};
        return nav;
    };
    UITabBarController *root = [UITabBarController new];
    root.viewControllers = @[
        tab([SPLChannelsController new], @"Canais", 0),
        tab([SPLBrowserController new], @"Navegador", 1),
        tab([SPLSettingsController new], @"CarPlay", 2)
    ];
    root.tabBar.barTintColor = SPLPanel(); root.tabBar.tintColor = SPLAccent();
    self.window.rootViewController = root; [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(SPLAppDelegate.class)); }
}
