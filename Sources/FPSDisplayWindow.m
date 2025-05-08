#import "FPSDisplayWindow.h"
#import "FPSCalculator.h"
#import "FPSGraphView.h"
#import "FPSThermalMonitor.h"
#import "FPSGameSupport.h"

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
        
        // Configure window properties for rootless compatibility
        
        // IMPORTANT: Try a completely different approach for rootless
        // Instead of relying on UIWindowLevel, which might be restricted,
        // we'll use UIScreen's scale and coordinateSpace to position our window
        // and enable a custom window mode that might bypass restrictions
        
        // Clear background and ensure alpha channel works properly
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.clipsToBounds = NO;
        
        // Make non-interactive to avoid gameplay disruption
        self.userInteractionEnabled = NO;
        
        // Attempt multiple window level approaches to bypass restrictions
        if (@available(iOS 13.0, *)) {
            // Try method 1: Use UIWindowScene's highest level possible
            self.windowLevel = UIWindowLevelStatusBar + 100000;
        } else {
            // For older iOS, use alert level + a very high value
            self.windowLevel = UIWindowLevelAlert + 10000;
        }
        
        // A critical configuration for rootless compatibility
        if ([self respondsToSelector:@selector(setCanResizeToFitContent:)]) {
            [self performSelector:@selector(setCanResizeToFitContent:) withObject:@YES];
        }
        
        // Use root level key window to avoid restrictions
        if ([self respondsToSelector:@selector(_setSecure:)]) {
            [self performSelector:@selector(_setSecure:) withObject:@NO];
        } else {
            // Try alternative private API access through NSInvocation for rootless
            SEL privateSel = NSSelectorFromString(@"_setSecure:");
            if ([self respondsToSelector:privateSel]) {
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
                                          [self methodSignatureForSelector:privateSel]];
                [invocation setSelector:privateSel];
                [invocation setTarget:self];
                BOOL no = NO;
                [invocation setArgument:&no atIndex:2];
                [invocation invoke];
            }
            
            // Try to set level via alternative method for rootless
            if ([UIWindow respondsToSelector:NSSelectorFromString(@"setWindow:level:")]) {
                SEL levelSetter = NSSelectorFromString(@"setWindow:level:");
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
                                          [UIWindow methodSignatureForSelector:levelSetter]];
                [invocation setSelector:levelSetter];
                [invocation setTarget:[UIWindow class]];
                
                // Cast self to void* to avoid type errors
                void *windowPtr = (__bridge void *)self;
                [invocation setArgument:&windowPtr atIndex:2];
                
                CGFloat level = 100000;
                [invocation setArgument:&level atIndex:3];
                [invocation invoke];
            }
        }
        
        // FPS label with rootless-compatible layer properties
        UILabel *label = [[UILabel alloc] init];
        label.font = [UIFont monospacedDigitSystemFontOfSize:16 weight:UIFontWeightBold];
        label.textAlignment = NSTextAlignmentCenter;
        label.layer.cornerRadius = 5;
        label.layer.masksToBounds = YES;
        label.layer.borderWidth = 1.0;
        label.layer.borderColor = [UIColor blackColor].CGColor;
        
        // Add special shadow to ensure visibility on any background
        label.layer.shadowColor = [UIColor blackColor].CGColor;
        label.layer.shadowOffset = CGSizeMake(0, 0);
        label.layer.shadowOpacity = 1.0;
        label.layer.shadowRadius = 3.0;
        
        // Set initial colors with stronger opacity
        if (@available(iOS 13.0, *)) {
            label.backgroundColor = [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.9];
            label.textColor = [UIColor systemGreenColor];
        } else {
            label.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.9];
            label.textColor = [UIColor greenColor];
        }
        
        // Use Auto Layout for positioning
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:label];
        self.fpsLabel = label;
        
        // Position the label in the top right corner by default
        [NSLayoutConstraint activateConstraints:@[
            [label.widthAnchor constraintEqualToConstant:80], // Slightly wider
            [label.heightAnchor constraintEqualToConstant:30],
            [label.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:10],
            [label.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10]
        ]];
        
        // Initialize with good defaults
        _colorCodingEnabled = YES;
        _goodFPSThreshold = 50.0;
        _mediumFPSThreshold = 30.0;
        _goodFPSColor = [UIColor greenColor];
        _mediumFPSColor = [UIColor yellowColor];
        _poorFPSColor = [UIColor redColor];
        _displayMode = FPSDisplayModeNormal;
        
        // Check for app filtering
        NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
        _isInPrivacyMode = ![self shouldShowInApp:currentBundleID];
        
        // Set initial visible state
        self.hidden = _isInPrivacyMode;
        
        // Apply saved preferences
        [self loadAppearanceFromPreferences];
        
        _isInitialized = YES;
        
        // Set an initial value to make sure the label is visible
        self.fpsLabel.text = @"FPS: --";
        
        // Log information about our window
        NSLog(@"FPSIndicator: Window initialized with level: %f, rootless: %@, bundle: %@", 
              self.windowLevel, 
              [[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb"] ? @"YES" : @"NO",
              currentBundleID);
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Public Methods

- (void)updateWithFPS:(double)fps {
    if (!self.fpsLabel || self.hidden || _isInPrivacyMode) return;
    
    // Calculate frame time in milliseconds (1000ms / fps)
    double frameTime = (fps > 0) ? (1000.0 / fps) : 0;
    
    // Update graph with the current frame time
    if (self.graphView && self.graphEnabled) {
        [self.graphView addFrameTime:frameTime];
    }
    
    // Format FPS based on display mode
    NSString *fpsText;
    switch (self.displayMode) {
        case FPSDisplayModeNormal:
            fpsText = [NSString stringWithFormat:@"%.1f FPS", fps];
            break;
        case FPSDisplayModeCompact:
            fpsText = [NSString stringWithFormat:@"%.1f", fps];
            break;
        case FPSDisplayModeDot:
            fpsText = @"●"; // Unicode dot character
            break;
        case FPSDisplayModeGraph:
            // In graph mode, show frame time instead of FPS
            fpsText = [NSString stringWithFormat:@"%.1f ms", frameTime];
            break;
    }
    
    // Update the UI on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        self.fpsLabel.text = fpsText;
        
        // Apply color coding if enabled
        if (self.colorCodingEnabled) {
            if (fps >= self.goodFPSThreshold) {
                self.fpsLabel.textColor = self.goodFPSColor;
            } else if (fps >= self.mediumFPSThreshold) {
                self.fpsLabel.textColor = self.mediumFPSColor;
            } else {
                self.fpsLabel.textColor = self.poorFPSColor;
            }
        }
        
        // Adjust label size based on display mode
        if (self.displayMode == FPSDisplayModeDot) {
            self.fpsLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
            // Create more circular appearance for dot mode
            self.fpsLabel.layer.cornerRadius = self.fpsLabel.bounds.size.height / 2;
        } else {
            // Use regular font for text modes
            self.fpsLabel.font = [UIFont monospacedDigitSystemFontOfSize:self.fontSize weight:UIFontWeightBold];
            self.fpsLabel.layer.cornerRadius = 5;
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
        NSLog(@"FPSIndicator: Hiding due to privacy mode for app: %@", [[NSBundle mainBundle] bundleIdentifier]);
        return;
    }
    
    self.hidden = !visible;
    NSLog(@"FPSIndicator: Setting visibility to %@", visible ? @"YES" : @"NO");
    
    if (visible) {
        // Show a debug message with important info
        NSLog(@"FPSIndicator: Making window visible at level %f with bundle ID %@", 
              self.windowLevel, [[NSBundle mainBundle] bundleIdentifier]);
              
        // Ensure the window is positioned correctly
        [self updateFrameForCurrentOrientation];
        
        // Force window to be key and visible
        [self makeKeyAndVisible];
        
        // Set an initial text to make sure label is visible
        if (!self.fpsLabel.text || [self.fpsLabel.text length] == 0) {
            self.fpsLabel.text = @"FPS";
        }
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
    
    // Load display mode
    if (prefs[@"displayMode"]) {
        self.displayMode = [prefs[@"displayMode"] integerValue];
        if (self.displayMode == FPSDisplayModeGraph && self.graphEnabled) {
            [self showGraphView];
        }
    }
    
    // Load thermal monitoring preference
    if (prefs[@"thermalMonitoringEnabled"]) {
        self.thermalMonitoringEnabled = [prefs[@"thermalMonitoringEnabled"] boolValue];
        if (self.thermalMonitoringEnabled) {
            [[FPSThermalMonitor sharedInstance] startMonitoring];
        }
    }
    
    // Load color coding preferences
    if (prefs[@"colorCodingEnabled"]) {
        self.colorCodingEnabled = [prefs[@"colorCodingEnabled"] boolValue];
    }
    
    if (prefs[@"goodFPSThreshold"]) {
        self.goodFPSThreshold = [prefs[@"goodFPSThreshold"] doubleValue];
    }
    
    if (prefs[@"mediumFPSThreshold"]) {
        self.mediumFPSThreshold = [prefs[@"mediumFPSThreshold"] doubleValue];
    }
    
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
    
    BOOL isInPrivacyList = [_privacyAppList containsObject:bundleID];
    
    // Log privacy mode status for debugging
    NSLog(@"FPSIndicator: Privacy check for %@ - In privacy list: %@", 
          bundleID, isInPrivacyList ? @"YES" : @"NO");
    
    return isInPrivacyList;
}

- (BOOL)shouldShowInApp:(NSString *)bundleID {
    if (!bundleID) return NO;
    
    // Check preferences to see which apps are enabled
    NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
    if (!prefs) {
        // If no preferences, default to show in all apps
        return YES;
    }
    
    NSArray *enabledApps = prefs[@"enabledApps"];
    if (!enabledApps || enabledApps.count == 0) {
        // Default to all apps if not specified
        return YES;
    }
    
    // If "*" is in the list, show in all apps (except privacy list)
    if ([enabledApps containsObject:@"*"]) {
        // But still check if this app is in the privacy list
        if ([self shouldActivatePrivacyModeForApp:bundleID]) {
            return NO;
        }
        return YES;
    }
    
    // Check for game categories
    if ([enabledApps containsObject:@"games"]) {
        if ([[FPSGameSupport sharedInstance] isGameApp:bundleID]) {
            return YES;
        }
    }
    
    // Check for game engines
    if ([enabledApps containsObject:@"unity"]) {
        if ([[FPSGameSupport sharedInstance] isUnityApp]) {
            return YES;
        }
    }
    
    if ([enabledApps containsObject:@"unreal"]) {
        if ([[FPSGameSupport sharedInstance] isUnrealApp]) {
            return YES;
        }
    }
    
    // Finally check if this specific app is enabled
    return [enabledApps containsObject:bundleID];
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

- (void)handleFPSLabelDoubleTap:(UITapGestureRecognizer *)doubleTap {
    if (doubleTap.state == UIGestureRecognizerStateRecognized) {
        // Cycle through display modes
        switch (self.displayMode) {
            case FPSDisplayModeNormal:
                self.displayMode = FPSDisplayModeCompact;
                break;
            case FPSDisplayModeCompact:
                self.displayMode = FPSDisplayModeDot;
                break;
            case FPSDisplayModeDot:
                if (self.graphEnabled) {
                    self.displayMode = FPSDisplayModeGraph;
                    // Show graph view with animation
                    [self showGraphView];
                } else {
                    self.displayMode = FPSDisplayModeNormal;
                }
                break;
            case FPSDisplayModeGraph:
                self.displayMode = FPSDisplayModeNormal;
                // Hide graph view with animation
                [self hideGraphView];
                break;
        }
        
        // Save display mode to preferences
        [self saveDisplayModeToPreferences];
        
        // Display a brief feedback toast
        NSString *modeName;
        switch (self.displayMode) {
            case FPSDisplayModeNormal:
                modeName = @"Normal Mode";
                break;
            case FPSDisplayModeCompact:
                modeName = @"Compact Mode";
                break;
            case FPSDisplayModeDot:
                modeName = @"Dot Mode";
                break;
            case FPSDisplayModeGraph:
                modeName = @"Graph Mode";
                break;
        }
        
        [self showToast:modeName];
    }
}

- (void)handleGraphViewTap:(UITapGestureRecognizer *)tap {
    if (tap.state == UIGestureRecognizerStateRecognized) {
        // Exit graph mode on tap
        self.displayMode = FPSDisplayModeNormal;
        [self hideGraphView];
        [self saveDisplayModeToPreferences];
        [self showToast:@"Normal Mode"];
    }
}

- (void)handleFPSLabelLongPress:(UILongPressGestureRecognizer *)longPress {
    if (longPress.state == UIGestureRecognizerStateBegan) {
        // Toggle thermal monitoring
        self.thermalMonitoringEnabled = !self.thermalMonitoringEnabled;
        
        if (self.thermalMonitoringEnabled) {
            [self showToast:@"Thermal Monitoring Enabled"];
            // Start monitoring
            [[FPSThermalMonitor sharedInstance] startMonitoring];
        } else {
            [self showToast:@"Thermal Monitoring Disabled"];
            // Stop monitoring
            [[FPSThermalMonitor sharedInstance] stopMonitoring];
            // Hide temperature label with animation
            [UIView animateWithDuration:0.3 animations:^{
                self.temperatureLabel.alpha = 0.0;
            }];
        }
        
        // Save thermal monitoring preference
        [self saveThermalMonitoringPreference];
    }
}

- (void)showGraphView {
    if (!self.graphView) return;
    
    // Start animation to show the graph
    [UIView animateWithDuration:0.3 animations:^{
        self.graphView.alpha = 1.0;
    }];
}

- (void)hideGraphView {
    if (!self.graphView) return;
    
    // Start animation to hide the graph
    [UIView animateWithDuration:0.3 animations:^{
        self.graphView.alpha = 0.0;
    }];
}

- (void)saveDisplayModeToPreferences {
    NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
    if (!prefs) prefs = [NSMutableDictionary dictionary];
    
    // Save display mode setting
    prefs[@"displayMode"] = @(self.displayMode);
    
    [prefs writeToFile:kPrefPath atomically:YES];
}

- (void)saveThermalMonitoringPreference {
    NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
    if (!prefs) prefs = [NSMutableDictionary dictionary];
    
    // Save thermal monitoring setting
    prefs[@"thermalMonitoringEnabled"] = @(self.thermalMonitoringEnabled);
    
    [prefs writeToFile:kPrefPath atomically:YES];
}

- (void)showToast:(NSString *)message {
    // Create a simple toast view
    UILabel *toastLabel = [[UILabel alloc] init];
    toastLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    toastLabel.textColor = [UIColor whiteColor];
    toastLabel.textAlignment = NSTextAlignmentCenter;
    toastLabel.font = [UIFont systemFontOfSize:12];
    toastLabel.text = message;
    toastLabel.alpha = 0.0;
    toastLabel.layer.cornerRadius = 10;
    toastLabel.clipsToBounds = YES;
    
    // Add to window
    [self addSubview:toastLabel];
    
    // Setup constraints
    toastLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [toastLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [toastLabel.bottomAnchor constraintEqualToAnchor:self.fpsLabel.topAnchor constant:-10],
        [toastLabel.widthAnchor constraintGreaterThanOrEqualToConstant:100],
        [toastLabel.heightAnchor constraintEqualToConstant:30]
    ]];
    
    // Animate in
    [UIView animateWithDuration:0.3 animations:^{
        toastLabel.alpha = 1.0;
    } completion:^(BOOL finished) {
        // Animate out after delay
        [UIView animateWithDuration:0.3 delay:1.0 options:0 animations:^{
            toastLabel.alpha = 0.0;
        } completion:^(BOOL finished) {
            [toastLabel removeFromSuperview];
        }];
    }];
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

- (void)thermalDataDidUpdate:(NSNotification *)notification {
    if (!self.thermalMonitoringEnabled) return;
    
    FPSThermalMonitor *monitor = [FPSThermalMonitor sharedInstance];
    
    // Update temperature label on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        // Show both CPU and GPU temperatures
        self.temperatureLabel.text = monitor.temperatureString;
        
        // Use thermal state color
        self.temperatureLabel.textColor = [monitor thermalStateColor];
        
        // Show the temperature label with animation if it's hidden
        if (self.temperatureLabel.alpha < 1.0) {
            [UIView animateWithDuration:0.3 animations:^{
                self.temperatureLabel.alpha = 1.0;
            }];
        }
        
        // If in graph mode, adjust graph position to accommodate temperature label
        if (self.displayMode == FPSDisplayModeGraph && self.graphView.alpha > 0) {
            [NSLayoutConstraint activateConstraints:@[
                [self.graphView.topAnchor constraintEqualToAnchor:self.temperatureLabel.bottomAnchor constant:5]
            ]];
        }
    });
}

@end