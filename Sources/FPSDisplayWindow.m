#import "FPSDisplayWindow.h"
#import "FPSCalculator.h"
#import "FPSGraphView.h"
#import "FPSThermalMonitor.h"

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
        
        // Initialize color coding properties with default values
        _colorCodingEnabled = YES;
        _goodFPSThreshold = 50.0;
        _mediumFPSThreshold = 30.0;
        _goodFPSColor = [UIColor greenColor];
        _mediumFPSColor = [UIColor yellowColor];
        _poorFPSColor = [UIColor redColor];
        
        // Initialize display mode to normal
        _displayMode = FPSDisplayModeNormal;
        _graphEnabled = YES;
        _thermalMonitoringEnabled = NO; // Default to off
        
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
        
        // Create and configure the temperature label
        UILabel *tempLabel = [[UILabel alloc] init];
        tempLabel.font = [UIFont systemFontOfSize:10];
        tempLabel.textAlignment = NSTextAlignmentCenter;
        tempLabel.layer.cornerRadius = 5;
        tempLabel.layer.masksToBounds = YES;
        tempLabel.backgroundColor = label.backgroundColor;
        tempLabel.textColor = label.textColor;
        tempLabel.alpha = 0.0; // Start hidden
        tempLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:tempLabel];
        self.temperatureLabel = tempLabel;
        
        // Create and configure the graph view
        FPSGraphView *graphView = [[FPSGraphView alloc] initWithFrame:CGRectMake(0, 0, 160, 80)];
        graphView.translatesAutoresizingMaskIntoConstraints = NO;
        graphView.alpha = 0.0; // Start hidden
        graphView.layer.cornerRadius = 5;
        [self addSubview:graphView];
        self.graphView = graphView;
        
        // Setup graph view gesture recognizers
        UITapGestureRecognizer *graphTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleGraphViewTap:)];
        [graphView addGestureRecognizer:graphTap];
        graphView.userInteractionEnabled = YES;
        
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
        
        // Graph view constraints - anchored to FPS label
        [NSLayoutConstraint activateConstraints:@[
            [graphView.widthAnchor constraintEqualToConstant:160],
            [graphView.heightAnchor constraintEqualToConstant:80],
            [graphView.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:5],
            [graphView.trailingAnchor constraintEqualToAnchor:label.trailingAnchor]
        ]];
        
        // Temperature label constraints - anchored below FPS label
        [NSLayoutConstraint activateConstraints:@[
            [tempLabel.widthAnchor constraintEqualToConstant:120],
            [tempLabel.heightAnchor constraintEqualToConstant:20],
            [tempLabel.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:5],
            [tempLabel.trailingAnchor constraintEqualToAnchor:label.trailingAnchor]
        ]];
        
        // Add pan gesture for repositioning
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleFPSLabelPan:)];
        [label addGestureRecognizer:pan];
        
        // Add double tap gesture for cycling display modes
        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleFPSLabelDoubleTap:)];
        doubleTap.numberOfTapsRequired = 2;
        [label addGestureRecognizer:doubleTap];
        
        // Add long press gesture for toggling thermal monitoring
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleFPSLabelLongPress:)];
        longPress.minimumPressDuration = 1.0; // 1 second long press
        [label addGestureRecognizer:longPress];
        
        // Make sure single tap doesn't interfere with double tap
        [pan requireGestureRecognizerToFail:doubleTap];
        [doubleTap requireGestureRecognizerToFail:longPress];
        
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
        
        // Register for thermal data updates
        [[NSNotificationCenter defaultCenter] addObserver:self
                                               selector:@selector(thermalDataDidUpdate:)
                                                   name:@"FPSThermalDataUpdatedNotification"
                                                 object:nil];
        
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