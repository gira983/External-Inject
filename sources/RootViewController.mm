//
//  RootViewController.mm
//

#import <notify.h>
#import "HUDHelper.h"
#import "MainApplication.h"
#import "RootViewController.h"
#import "UIApplication+Private.h"
#import "../esp/drawing_view/obfusheader.h"

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleID;
@end

@implementation RootViewController {
    UIButton *mainButton;
    UILabel  *tgLabel;
    UIImageView *iconImageView;
    NSLayoutConstraint *mainButtonCenterYConstraint;
    BOOL isRemoteHUDActive;
}

- (BOOL)isHUDEnabled { return IsHUDEnabled(); }
- (void)setHUDEnabled:(BOOL)enabled { SetHUDEnabled(enabled); }

- (void)loadView {
    CGRect bounds = UIScreen.mainScreen.bounds;
    self.view = [[UIView alloc] initWithFrame:bounds];
    self.view.backgroundColor = [UIColor blackColor];

    self.backgroundView = [[UIView alloc] initWithFrame:bounds];
    self.backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.backgroundView.backgroundColor  = [UIColor colorWithRed:0.05 green:0.05 blue:0.08 alpha:1];
    [self.view addSubview:self.backgroundView];

    // Gradient bg
    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.frame  = bounds;
    grad.colors = @[(id)[UIColor colorWithRed:0.05 green:0.05 blue:0.12 alpha:1].CGColor,
                    (id)[UIColor colorWithRed:0.08 green:0.02 blue:0.15 alpha:1].CGColor];
    grad.startPoint = CGPointMake(0, 0);
    grad.endPoint   = CGPointMake(1, 1);
    [self.backgroundView.layer insertSublayer:grad atIndex:0];

    // Icon
    iconImageView = [[UIImageView alloc] init];
    iconImageView.contentMode     = UIViewContentModeScaleAspectFit;
    iconImageView.layer.cornerRadius   = 20.f;
    iconImageView.layer.masksToBounds  = YES;
    iconImageView.image = [UIImage imageNamed:@"icon.png"];
    [self.backgroundView addSubview:iconImageView];

    // Run button
    mainButton = [UIButton buttonWithType:UIButtonTypeSystem];
    mainButton.layer.cornerRadius  = 14.f;
    mainButton.layer.masksToBounds = YES;
    mainButton.backgroundColor = [UIColor colorWithRed:0.3 green:0.1 blue:0.6 alpha:1];
    [mainButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    mainButton.titleLabel.font = [UIFont boldSystemFontOfSize:24.f];
    [mainButton addTarget:self action:@selector(tapMainButton:) forControlEvents:UIControlEventTouchUpInside];
    // Glow
    mainButton.layer.shadowColor  = [UIColor colorWithRed:0.5 green:0.2 blue:1 alpha:1].CGColor;
    mainButton.layer.shadowOffset = CGSizeZero;
    mainButton.layer.shadowRadius = 12.f;
    mainButton.layer.shadowOpacity= 0.7f;
    [self.backgroundView addSubview:mainButton];

    // iOS version label
    UILabel *iosLbl = [[UILabel alloc] init];
    iosLbl.text = [NSString stringWithFormat:@(OBF("iOS %@")), [[UIDevice currentDevice] systemVersion]];
    iosLbl.textColor = [UIColor colorWithWhite:1 alpha:0.4];
    iosLbl.font = [UIFont systemFontOfSize:13];
    iosLbl.textAlignment = NSTextAlignmentCenter;
    iosLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.backgroundView addSubview:iosLbl];

    // Telegram label (кликабельный)
    tgLabel = [[UILabel alloc] init];
    tgLabel.text = @(OBF("t.me/g1reev7"));
    tgLabel.textColor = [UIColor colorWithRed:0.5 green:0.7 blue:1 alpha:1];
    tgLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    tgLabel.textAlignment = NSTextAlignmentCenter;
    tgLabel.userInteractionEnabled = YES;
    tgLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UITapGestureRecognizer *tgTap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(openTelegram)];
    [tgLabel addGestureRecognizer:tgTap];
    [self.backgroundView addSubview:tgLabel];

    // Layout
    iconImageView.translatesAutoresizingMaskIntoConstraints = NO;
    mainButton.translatesAutoresizingMaskIntoConstraints    = NO;

    mainButtonCenterYConstraint = [mainButton.centerYAnchor
        constraintEqualToAnchor:self.backgroundView.centerYAnchor constant:-20.f];

    UILayoutGuide *safe = self.backgroundView.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [iconImageView.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [iconImageView.bottomAnchor  constraintEqualToAnchor:mainButton.topAnchor constant:-28],
        [iconImageView.widthAnchor   constraintEqualToConstant:90],
        [iconImageView.heightAnchor  constraintEqualToConstant:90],

        mainButtonCenterYConstraint,
        [mainButton.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [mainButton.widthAnchor   constraintEqualToConstant:220],
        [mainButton.heightAnchor  constraintEqualToConstant:58],

        [tgLabel.topAnchor    constraintEqualToAnchor:mainButton.bottomAnchor constant:16],
        [tgLabel.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],

        [iosLbl.topAnchor     constraintEqualToAnchor:safe.topAnchor constant:12],
        [iosLbl.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
    ]];

    [self reloadMainButtonState];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // При открытии приложения — редирект в ТГ
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [self openTelegram];
    });
}

- (void)openTelegram {
    NSURL *url = [NSURL URLWithString:@(OBF("https://t.me/g1reev7"))];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)reloadMainButtonState {
    isRemoteHUDActive = [self isHUDEnabled];
    [mainButton setTitle:(isRemoteHUDActive ? @(OBF("Stop")) : @(OBF("Run")))
               forState:UIControlStateNormal];
    mainButton.backgroundColor = isRemoteHUDActive
        ? [UIColor colorWithRed:0.6 green:0.1 blue:0.1 alpha:1]  // красный = Stop
        : [UIColor colorWithRed:0.3 green:0.1 blue:0.6 alpha:1]; // фиолетовый = Run
}

- (void)tapMainButton:(UIButton *)sender {
    BOOL isNowEnabled = [self isHUDEnabled];
    [self setHUDEnabled:!isNowEnabled];
    isNowEnabled = !isNowEnabled;

    if (isNowEnabled) {
        // Запустили HUD — открываем FF
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3*NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [[LSApplicationWorkspace defaultWorkspace]
                openApplicationWithBundleID:@(OBF("com.dts.freefireth"))];
        });
    }

    self.backgroundView.userInteractionEnabled = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5*NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self reloadMainButtonState];
        self.backgroundView.userInteractionEnabled = YES;
    });
}

- (void)traitCollectionDidChange:(UITraitCollection *)prev {
    [super traitCollectionDidChange:prev];
    UIUserInterfaceSizeClass vc = self.traitCollection.verticalSizeClass;
    mainButtonCenterYConstraint.constant = (vc == UIUserInterfaceSizeClassCompact) ? -10 : -20;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

@end
