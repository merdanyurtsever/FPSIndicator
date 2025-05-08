#import "FPSDisplayWindow.h"
#import "FPSCalculator.h"

// Constants
#define kFPSLabelWidth 65
#define kFPSLabelHeight 30

// Privacy mode app list - apps where FPS indicator should be hidden
static NSArray *kPrivacyModeApps;

@implementation FPSDisplayWindow {
    BOOL _isInitialized;
    BOOL _isInPrivacyMode;
    NSMutableArray *_privacyAppList;
}

#pragma mark - Lifecycle

+ (instancetype)sharedInstance {
    static FPSDisplayWindow *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Use the appropriate initializer based on iOS version
        if (@available(iOS 13.0, *)) {
            UIWindowScene *scene = nil;
            for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
                if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                    scene = windowScene;
                    break;
                }
            }
            if (scene) {
                sharedInstance = [[FPSDisplayWindow alloc] initWithWindowScene:scene];
            } else {
                sharedInstance = [[FPSDisplayWindow alloc] init];
            }
        } else {
            sharedInstance = [[FPSDisplayWindow alloc] init];
        }
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        if (!_isInitialized) {
            [self commonInit];
        }
    }
    return self;
}

- (instancetype)initWithWindowScene:(UIWindowScene *)windowScene {
    if (@available(iOS 13.0, *)) {
        if (self = [super initWithWindowScene:windowScene]) {
            if (!_isInitialized) {
                [self commonInit];
            }
        }
        return self;
    }
    return [self init];
}

- (void)commonInit {
    @synchronized(self) {
        if (_isInitialized) return;
        
        // Initialize privacy app list
        _privacyAppList = [NSMutableArray array];
        [self loadPrivacyAppList];
        
        // Configure window properties
        self.windowLevel = UIWindowLevelStatusBar + 100;
        self.userInteractionEnabled = YES;
        self.backgroundColor = [UIColor clearColor];
        self.hidden = NO;
        
        // Check for privacy mode
        NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
        _isInPrivacyMode = [self shouldActivatePrivacyModeForApp:currentBundleID];
        if (_isInPrivacyMode) {
            self.hidden = YES;
        }
        
        // Create and configure the FPS label
        UILabel *label = [[UILabel alloc] init];
        label.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightBold];
        label.textAlignment = NSTextAlignmentCenter;
        label.layer.cornerRadius = 5;
        label.layer.masksToBounds = YES;
        
        if (@available(iOS 13.0, *)) {
            self.backgroundColor = [UIColor clearColor];
            label.backgroundColor = [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.7];
            label.textColor = [UIColor labelColor];
        } else {
            label.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
            label.textColor = [UIColor yellowColor];
        }
        
        // Use Auto Layout for better positioning
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:label];
        self.fpsLabel = label;
        
        // Initial positioning constraints
        [NSLayoutConstraint activateConstraints:@[
            [label.widthAnchor constraintEqualToConstant:kFPSLabelWidth],
            [label.heightAnchor constraintEqualToConstant:kFPSLabelHeight],
            [label.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:5],
            [label.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-5]
        ]];
        
        // Add pan gesture for repositioning
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleFPSLabelPan:)];
        [label addGestureRecognizer:pan];
        label.userInteractionEnabled = YES;
        
        // Load saved position from preferences
        [self loadPositionFromPreferences];
        
        // Register for notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                selector:@selector(orientationDidChange:)
                                                    name:UIDeviceOrientationDidChangeNotification
                                                  object:nil];
        
        if (@available(iOS 11.0, *)) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                    selector:@selector(screenCaptureDidChange:)
                                                        name:UIScreenCapturedDidChangeNotification
                                                      object:nil];
        }
        
        if (@available(iOS 13.0, *)) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                    selector:@selector(sceneDidBecomeActive:)
                                                        name:UISceneDidActivateNotification
                                                      object:nil];
        }
        
        // Apply appearance from saved preferences
        [self loadAppearanceFromPreferences];
        
        _isInitialized = YES;
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Public Methods

- (void)updateWithFPS:(double)fps {
    if (!self.fpsLabel || self.hidden || _isInPrivacyMode) return;
    
    // Format FPS with different colors based on performance thresholds
    NSString *fpsText = [NSString stringWithFormat:@"%.1f", fps];
    
    // Update the UI on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        self.fpsLabel.text = fpsText;
        
        // Color-code based on performance
        if (fps >= 50) {
            self.fpsLabel.textColor = [UIColor greenColor];
        } else if (fps >= 30) {
            self.fpsLabel.textColor = [UIColor yellowColor];
        } else {
            self.fpsLabel.textColor = [UIColor redColor];
        }
    });
}

- (void)applyPositionPreset:(PositionPreset)preset {
    CGRect bounds = [[UIScreen mainScreen] bounds];
    CGPoint position = CGPointZero;
    
    // Calculate position based on preset
    switch (preset) {
        case PositionPresetTopLeft:
            position = CGPointMake(kFPSLabelWidth/2 + 10, 30);
            break;
        case PositionPresetTopRight:
            position = CGPointMake(bounds.size.width - kFPSLabelWidth/2 - 10, 30);
            break;
        case PositionPresetBottomLeft:
            position = CGPointMake(kFPSLabelWidth/2 + 10, bounds.size.height - 30);
            break;
        case PositionPresetBottomRight:
            position = CGPointMake(bounds.size.width - kFPSLabelWidth/2 - 10, bounds.size.height - 30);
            break;
        case PositionPresetCustom:
            // Do nothing, keep custom position
            return;
    }
    
    // Update position on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        self.fpsLabel.center = position;
        self.positionPreset = preset;
        [self saveCurrentPosition];
    });
}

- (void)saveCurrentPosition {
    if (!self.fpsLabel) return;
    
    NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
    if (!prefs) prefs = [NSMutableDictionary dictionary];
    
    // Save both position and preset
    prefs[@"labelPosition"] = @[@(self.fpsLabel.center.x), @(self.fpsLabel.center.y)];
    prefs[@"positionPreset"] = @(self.positionPreset);
    
    [prefs writeToFile:kPrefPath atomically:YES];
}

- (void)updateFrameForCurrentOrientation {
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = self.windowScene;
        if (!scene) return;
        
        self.frame = scene.coordinateSpace.bounds;
    } else {
        self.frame = [[UIScreen mainScreen] bounds];
    }
    
    // If using a preset position, reapply it for the new orientation
    if (self.positionPreset != PositionPresetCustom) {
        [self applyPositionPreset:self.positionPreset];
    }
}

- (void)updateAppearanceWithPreferences:(NSDictionary *)preferences {
    if (!preferences) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Update text color if specified
        if (preferences[@"color"]) {
            NSString *colorString = preferences[@"color"];
            self.fpsLabel.textColor = [self colorFromHexString:colorString fallback:[UIColor greenColor]];
        }
        
        // Update background color if specified
        if (preferences[@"backgroundColor"]) {
            NSString *bgColorString = preferences[@"backgroundColor"];
            UIColor *bgColor = [self colorFromHexString:bgColorString fallback:[UIColor blackColor]];
            self.fpsLabel.backgroundColor = [bgColor colorWithAlphaComponent:self.backgroundAlpha];
        }
        
        // Update background opacity if specified
        if (preferences[@"backgroundOpacity"]) {
            self.backgroundAlpha = [preferences[@"backgroundOpacity"] floatValue];
            UIColor *currentBgColor = self.fpsLabel.backgroundColor;
            self.fpsLabel.backgroundColor = [currentBgColor colorWithAlphaComponent:self.backgroundAlpha];
        }
        
        // Update font size if specified
        if (preferences[@"fontSize"]) {
            self.fontSize = [preferences[@"fontSize"] floatValue];
            self.fpsLabel.font = [UIFont monospacedDigitSystemFontOfSize:self.fontSize weight:UIFontWeightBold];
        }
        
        // Update privacy app list if specified
        if (preferences[@"privacyApps"]) {
            _privacyAppList = [preferences[@"privacyApps"] mutableCopy];
            // Check if current app is in privacy list
            NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
            _isInPrivacyMode = [self shouldActivatePrivacyModeForApp:currentBundleID];
            self.hidden = _isInPrivacyMode;
        }
    });
}

- (void)setVisible:(BOOL)visible {
    // Don't show if we're in privacy mode
    if (_isInPrivacyMode) {
        self.hidden = YES;
        return;
    }
    
    self.hidden = !visible;
    
    if (visible) {
        [self makeKeyAndVisible];
    }
}

- (BOOL)activatePrivacyModeForApp:(NSString *)bundleID {
    if (!bundleID) return NO;
    
    _isInPrivacyMode = [self shouldActivatePrivacyModeForApp:bundleID];
    self.hidden = _isInPrivacyMode;
    
    return _isInPrivacyMode;
}

#pragma mark - Private Methods

- (void)loadPositionFromPreferences {
    NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
    if (!prefs) return;
    
    // Load position preset
    if (prefs[@"positionPreset"]) {
        self.positionPreset = [prefs[@"positionPreset"] integerValue];
        [self applyPositionPreset:self.positionPreset];
    } else {
        // Load custom position if available
        NSArray *position = prefs[@"labelPosition"];
        if (position && position.count == 2) {
            self.positionPreset = PositionPresetCustom;
            CGPoint center = CGPointMake([position[0] floatValue], [position[1] floatValue]);
            self.fpsLabel.center = center;
        } else {
            // Default to top right
            self.positionPreset = PositionPresetTopRight;
            [self applyPositionPreset:self.positionPreset];
        }
    }
}

- (void)loadAppearanceFromPreferences {
    NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
    if (!prefs) return;
    
    [self updateAppearanceWithPreferences:prefs];
}

- (void)loadPrivacyAppList {
    NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
    if (!prefs) return;
    
    if (prefs[@"privacyApps"]) {
        _privacyAppList = [prefs[@"privacyApps"] mutableCopy];
    } else {
        // Default privacy list - banking and financial apps
        _privacyAppList = [@[
            @"com.apple.Passbook",
            @"com.paypal.PPClient",
            @"com.venmo.TouchFree",
            @"com.chase.sig.Chase"
        ] mutableCopy];
    }
}

- (BOOL)shouldActivatePrivacyModeForApp:(NSString *)bundleID {
    if (!bundleID || !_privacyAppList) return NO;
    
    return [_privacyAppList containsObject:bundleID];
}

- (UIColor *)colorFromHexString:(NSString *)hexString fallback:(UIColor *)fallbackColor {
    if (!hexString || [hexString length] == 0) {
        return fallbackColor;
    }
    
    // Remove # if present
    if ([hexString hasPrefix:@"#"]) {
        hexString = [hexString substringFromIndex:1];
    }
    
    // Convert hex to color
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner scanHexInt:&rgbValue];
    
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16) / 255.0
                          green:((rgbValue & 0x00FF00) >> 8) / 255.0
                           blue:(rgbValue & 0x0000FF) / 255.0
                          alpha:1.0];
}

#pragma mark - Event Handlers

- (void)handleFPSLabelPan:(UIPanGestureRecognizer *)pan {
    if (!self.fpsLabel) return;
    
    CGPoint translation = [pan translationInView:self];
    CGPoint newCenter = CGPointMake(self.fpsLabel.center.x + translation.x,
                                  self.fpsLabel.center.y + translation.y);
    
    // Keep within bounds
    CGRect bounds = self.bounds;
    CGFloat halfWidth = self.fpsLabel.bounds.size.width / 2.0;
    CGFloat halfHeight = self.fpsLabel.bounds.size.height / 2.0;
    newCenter.x = MIN(MAX(newCenter.x, halfWidth), bounds.size.width - halfWidth);
    newCenter.y = MIN(MAX(newCenter.y, halfHeight), bounds.size.height - halfHeight);
    
    self.fpsLabel.center = newCenter;
    [pan setTranslation:CGPointZero inView:self];
    
    // When dragging, we're in custom position mode
    self.positionPreset = PositionPresetCustom;
    
    if (pan.state == UIGestureRecognizerStateEnded) {
        [self saveCurrentPosition];
    }
}

#pragma mark - Notifications

- (void)orientationDidChange:(NSNotification *)notification {
    [self updateFrameForCurrentOrientation];
}

- (void)screenCaptureDidChange:(NSNotification *)notification {
    if (@available(iOS 11.0, *)) {
        UIScreen *screen = [UIScreen mainScreen];
        BOOL isScreenBeingCaptured = screen.isCaptured;
        
        // Hide FPS indicator during screen recording
        if (isScreenBeingCaptured) {
            self.hidden = YES;
        } else {
            // Only show if we're not in privacy mode
            self.hidden = _isInPrivacyMode;
        }
    }
}

- (void)sceneDidBecomeActive:(NSNotification *)notification {
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = notification.object;
        if (![scene isKindOfClass:[UIWindowScene class]]) return;
        
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            self.windowScene = scene;
            [self updateFrameForCurrentOrientation];
        }
    }
}

@end