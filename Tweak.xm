#import <notify.h>
#import <substrate.h>
#import <objc/runtime.h>

// Define constants at the top level
#define kFPSLabelWidth 50
#define kFPSLabelHeight 20
#define kPrefPath @THEOS_PACKAGE_INSTALL_PREFIX"/var/mobile/Library/Preferences/com.fpsindicator.plist"

static NSString *const kPUBGProcessNames[] = {
    @"com.tencent.ig",
    @"com.pubg.krmobile",
    @"com.tencent.tmgp.pubgmhd"
};

// Forward declarations
enum FPSMode{
    kModeAverage=1,
    kModePerSecond
};

// Used for multiple scene support
static NSMapTable *sceneToWindowMap;

@interface FPSWindow : UIWindow
@property (nonatomic, strong) UILabel *fpsLabel;
@property (nonatomic) CGPoint lastPosition;
@property (nonatomic, strong) UIColor *labelColor;
@property (nonatomic, assign) BOOL isInitialized;
- (void)updateFPSLabelPosition;
- (void)handleFPSLabelPan:(UIPanGestureRecognizer *)pan;
@end

// Keep track of existing window
static FPSWindow *fpsWindow = nil;
static dispatch_queue_t fpsQueue;
static dispatch_source_t _timer;
static BOOL enabled = YES;
static enum FPSMode fpsMode = kModeAverage;
static BOOL isLowPowerMode = NO;
static BOOL isScreenRecording = NO;

@implementation FPSWindow

- (instancetype)init {
    if (self = [super init]) {
        if (!self.isInitialized) {
            [self commonInit];
        }
    }
    return self;
}

- (instancetype)initWithWindowScene:(UIWindowScene *)windowScene {
    if (self = [super initWithWindowScene:windowScene]) {
        if (!self.isInitialized) {
            [self commonInit];
        }
    }
    return self;
}

- (void)commonInit {
    @synchronized(self) {
        if (self.isInitialized) return;
        
        self.windowLevel = UIWindowLevelStatusBar + 100;
        self.userInteractionEnabled = YES;
        self.backgroundColor = [UIColor clearColor];
        self.hidden = NO;
        
        if (@available(iOS 13.0, *)) {
            // Set window scene if available
            for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    self.windowScene = scene;
                    break;
                }
            }
        }
        
        UILabel *label = [[UILabel alloc] init];
        label.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightBold];
        label.textAlignment = NSTextAlignmentRight;
        label.layer.cornerRadius = 5;
        label.layer.masksToBounds = YES;
        
        if (@available(iOS 13.0, *)) {
            label.backgroundColor = [UIColor systemBackgroundColor];
            label.textColor = [UIColor labelColor];
        } else {
            label.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
            label.textColor = [UIColor yellowColor];
        }
        
        // Use Auto Layout
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:label];
        self.fpsLabel = label;
        
        [NSLayoutConstraint activateConstraints:@[
            [label.widthAnchor constraintEqualToConstant:kFPSLabelWidth],
            [label.heightAnchor constraintEqualToConstant:kFPSLabelHeight],
            [label.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:5],
            [label.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-5]
        ]];
        
        // Add pan gesture
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleFPSLabelPan:)];
        [label addGestureRecognizer:pan];
        label.userInteractionEnabled = YES;
        
        if (isPUBGProcess()) {
            self.windowLevel = UIWindowLevelStatusBar + 1000;
            label.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
            label.font = [UIFont monospacedDigitSystemFontOfSize:16 weight:UIFontWeightBold];
        }
        
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
        
        self.isInitialized = YES;
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // Clean up any resources
    if (_timer) {
        dispatch_source_cancel(_timer);
        _timer = nil;
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

- (void)updateFrameForCurrentOrientation {
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = self.windowScene;
        if (!scene) return;
        
        self.frame = scene.coordinateSpace.bounds;
        [self updateFPSLabelPosition];
    }
}

- (void)updateFPSLabelPosition {
    if (!self.fpsLabel) return;
    
    UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = self.windowScene;
        if (scene) {
            orientation = scene.interfaceOrientation;
        }
    }
    
    CGRect bounds = [[UIScreen mainScreen] bounds];
    CGFloat safeOffsetY = 0;
    CGFloat safeOffsetX = 0;
    
    if (@available(iOS 11.0, *)) {
        UIEdgeInsets safeArea = self.safeAreaInsets;
        if (UIInterfaceOrientationIsPortrait(orientation)) {
            safeOffsetY = safeArea.top;
            if (@available(iOS 16.0, *)) {
                if (safeArea.top > 50) {
                    safeOffsetY += 10;
                }
            }
        } else {
            safeOffsetX = safeArea.right;
        }
    }
    
    CGRect frame = self.fpsLabel.frame;
    frame.origin = CGPointMake(bounds.size.width - kFPSLabelWidth - 5 - safeOffsetX, safeOffsetY);
    self.fpsLabel.frame = frame;
}

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
    
    if (pan.state == UIGestureRecognizerStateEnded) {
        // Save position
        NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:@THEOS_PACKAGE_INSTALL_PREFIX"/var/mobile/Library/Preferences/com.fpsindicator.plist"];
        if (!prefs) prefs = [NSMutableDictionary dictionary];
        prefs[@"labelPosition"] = @[@(newCenter.x), @(newCenter.y)];
        [prefs writeToFile:@THEOS_PACKAGE_INSTALL_PREFIX"/var/mobile/Library/Preferences/com.fpsindicator.plist" atomically:YES];
    }
}

- (void)orientationDidChange:(NSNotification *)notification {
    [self updateFrameForCurrentOrientation];
}

- (void)screenCaptureDidChange:(NSNotification *)notification {
    if (@available(iOS 11.0, *)) {
        UIScreen *screen = [UIScreen mainScreen];
        BOOL isScreenBeingCaptured = screen.isCaptured;
        
        // Hide FPS indicator during screen recording if needed
        if (isScreenBeingCaptured) {
            self.hidden = YES;
        } else {
            self.hidden = !enabled;
        }
    }
}

/**
 * Updates window layout based on the current scene
 * Ensures FPS indicator is properly positioned in multi-window/Stage Manager scenarios
 */
- (void)updateSceneHandling {
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = self.windowScene;
        if (!scene) return;
        
        // Update frame to match the current scene's bounds
        self.frame = scene.coordinateSpace.bounds;
        
        // Update label position based on orientation
        [self updateFPSLabelPosition];
        
        // Adjust window level if needed
        if (isPUBGProcess()) {
            self.windowLevel = UIWindowLevelStatusBar + 1000;
        } else {
            self.windowLevel = UIWindowLevelStatusBar + 100;
        }
    }
}

@end

// Helper functions
static UIColor *parseColorString(NSString *colorString, UIColor *fallbackColor) {
    if (!colorString || [colorString length] == 0) {
        return fallbackColor ?: [UIColor whiteColor];
    }

    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:colorString];
    [scanner setScanLocation:1]; // Skip the # character
    [scanner scanHexInt:&rgbValue];

    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16) / 255.0
                           green:((rgbValue & 0x00FF00) >> 8) / 255.0
                            blue:(rgbValue & 0x0000FF) / 255.0
                           alpha:1.0];
}

static BOOL isPUBGProcess() {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    for (int i = 0; i < sizeof(kPUBGProcessNames)/sizeof(kPUBGProcessNames[0]); i++) {
        if ([bundleID isEqualToString:kPUBGProcessNames[i]]) {
            return YES;
        }
    }
    return NO;
}

static void updateFPSLabelPosition(void) {
    if (!fpsWindow || !fpsWindow.fpsLabel) return;
    
    UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = fpsWindow.windowScene;
        if (scene) {
            orientation = scene.interfaceOrientation;
        }
    }
    
    CGRect bounds = [[UIScreen mainScreen] bounds];
    CGFloat safeOffsetY = 0;
    CGFloat safeOffsetX = 0;
    
    if (@available(iOS 11.0, *)) {
        UIEdgeInsets safeArea = fpsWindow.safeAreaInsets;
        if (UIInterfaceOrientationIsPortrait(orientation)) {
            safeOffsetY = safeArea.top;
            if (@available(iOS 16.0, *)) {
                if (safeArea.top > 50) {
                    safeOffsetY += 10;
                }
            }
        } else {
            safeOffsetX = safeArea.right;
        }
    }
    
    CGRect frame = fpsWindow.fpsLabel.frame;
    frame.origin = CGPointMake(bounds.size.width - kFPSLabelWidth - 5 - safeOffsetX, safeOffsetY);
    fpsWindow.fpsLabel.frame = frame;
}

static void updateFPSRefreshRate(void) {
    if (!_timer) return;
    
    // Adjust refresh rate based on power mode
    NSTimeInterval interval = isLowPowerMode ? (1.0/2.0) : (1.0/5.0);
    dispatch_source_set_timer(_timer, dispatch_walltime(NULL, 0), interval * NSEC_PER_SEC, 0);
}

static void handlePowerModeChange(void) {
    if (@available(iOS 9.0, *)) {
        isLowPowerMode = [[NSProcessInfo processInfo] isLowPowerModeEnabled];
        updateFPSRefreshRate();
    }
}

static void handleScreenRecording(void) {
    if (@available(iOS 11.0, *)) {
        UIScreen *screen = [UIScreen mainScreen];
        isScreenRecording = screen.isCaptured;
        
        // Hide FPS indicator during screen recording if needed
        if (isScreenRecording) {
            fpsWindow.hidden = YES;
        } else {
            fpsWindow.hidden = !enabled;
        }
    }
}

static void loadPref() {
    NSLog(@"loadPref: Loading preferences");
    NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
    if (!prefs) prefs = [NSMutableDictionary dictionary];
    
    // Get settings with defaults
    enabled = prefs[@"enabled"] ? [prefs[@"enabled"] boolValue] : YES;
    fpsMode = prefs[@"fpsMode"] ? (enum FPSMode)[prefs[@"fpsMode"] intValue] : kModeAverage;
    if (fpsMode == 0) fpsMode = kModeAverage;
    
    NSString *colorString = prefs[@"color"] ?: @"#ffff00";
    UIColor *color = parseColorString(colorString, nil);
    
    // Apply settings on main thread to avoid UI inconsistencies
    dispatch_async(dispatch_get_main_queue(), ^{
        if (fpsWindow) {
            fpsWindow.hidden = !enabled || isScreenRecording;
            fpsWindow.fpsLabel.textColor = color;
            
            // Restore saved position if available
            NSArray *position = prefs[@"labelPosition"];
            if (position && position.count == 2) {
                CGPoint center = CGPointMake([position[0] floatValue], [position[1] floatValue]);
                fpsWindow.fpsLabel.center = center;
            }
        }
        
        // Notify preference bundle of changes
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                            CFSTR("com.fpsindicator/prefsChanged"),
                                            NULL, NULL, YES);
    });
}

double FPSavg = 0;
double FPSPerSecond = 0;

/**
 * Updates the FPS label with calculated frame rates
 * Uses a dispatch timer to periodically update the UI
 * Adjusts refresh rate based on low power mode
 */
static void startRefreshTimer(){
    if (_timer) {
        dispatch_source_cancel(_timer);
        _timer = nil;
    }
    
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    NSTimeInterval interval = isLowPowerMode ? (1.0/2.0) : (1.0/5.0);
    dispatch_source_set_timer(_timer, dispatch_walltime(NULL, 0), interval * NSEC_PER_SEC, 0);

    dispatch_source_set_event_handler(_timer, ^{
        if (!fpsWindow || !fpsWindow.fpsLabel) return;
        
        NSString *fpsText;
        switch(fpsMode){
            case kModeAverage:
                fpsText = [NSString stringWithFormat:@"%.1lf",FPSavg];
                break;
            case kModePerSecond:
                fpsText = [NSString stringWithFormat:@"%.1lf",FPSPerSecond];
                break;
            default:
                fpsText = @"--";
                break;
        }
        
        fpsWindow.fpsLabel.text = fpsText;
        
        // Only log FPS values in debug builds
        #ifdef DEBUG
        NSLog(@"FPS - Avg: %.1lf Per Second: %.1lf", FPSavg, FPSPerSecond);
        #endif
    });
    
    dispatch_resume(_timer); 
}

static void setupFPSWindow(void) {
    if (!fpsWindow) {
        if (@available(iOS 13.0, *)) {
            UIWindowScene *scene = nil;
            for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
                if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                    scene = windowScene;
                    break;
                }
            }
            fpsWindow = [[FPSWindow alloc] initWithWindowScene:scene];
        } else {
            fpsWindow = [[FPSWindow alloc] init];
        }
        
        fpsWindow.frame = [[UIScreen mainScreen] bounds];
        // No need to duplicate initialization code as it's already handled in commonInit
        [fpsWindow makeKeyAndVisible];
    }
}

static void setupFPSWindowForScene(UIWindowScene *scene) {
    if (!scene) return;
    
    @synchronized(sceneToWindowMap) {
        // Check if we already have a window for this scene
        if ([sceneToWindowMap objectForKey:scene]) return;
        
        FPSWindow *window = [[FPSWindow alloc] initWithWindowScene:scene];
        window.windowScene = scene;
        window.frame = scene.coordinateSpace.bounds;
        
        // Window is already configured through commonInit
        [sceneToWindowMap setObject:window forKey:scene];
        [window makeKeyAndVisible];
    }
}

#pragma mark ui
%group ui
%hook UIWindow
- (void)layoutSubviews {
    %orig;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if ([self isKindOfClass:[FPSWindow class]]) return;
        
        // Use the common setupFPSWindow method instead of recreating it here
        setupFPSWindow();
        
        // Register for notifications
        if (@available(iOS 9.0, *)) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                selector:@selector(powerModeDidChange:)
                name:NSProcessInfoPowerStateDidChangeNotification
                object:nil];
            handlePowerModeChange();
        }
        
        if (@available(iOS 11.0, *)) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                selector:@selector(screenCaptureDidChange:)
                name:UIScreenCapturedDidChangeNotification
                object:nil];
            handleScreenRecording();
        }
        
        loadPref();
        startRefreshTimer();
    });
}

%new
- (void)powerModeDidChange:(NSNotification *)notification {
    handlePowerModeChange();
}

%new
- (void)screenCaptureDidChange:(NSNotification *)notification {
    handleScreenRecording();
}
%end
%end//ui

// credits to https://github.com/masagrator/NX-FPS/blob/master/source/main.cpp#L64
// Thread-safe FPS calculation
void frameTick(){
    static dispatch_queue_t fpsQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fpsQueue = dispatch_queue_create("com.fpsindicator.frameTick", DISPATCH_QUEUE_SERIAL);
    });
    
    dispatch_async(fpsQueue, ^{
        static double FPS_temp = 0;
        static double starttick = 0;
        static double endtick = 0;
        static double deltatick = 0;
        static double frameend = 0;
        static double framedelta = 0;
        static double frameavg = 0;
        
        if (starttick == 0) starttick = CACurrentMediaTime()*1000.0;
        endtick = CACurrentMediaTime()*1000.0;
        framedelta = endtick - frameend;
        frameavg = ((9*frameavg) + framedelta) / 10;
        FPSavg = 1000.0f / (double)frameavg;
        frameend = endtick;
        
        FPS_temp++;
        deltatick = endtick - starttick;
        if (deltatick >= 1000.0f) {
            starttick = CACurrentMediaTime()*1000.0;
            FPSPerSecond = FPS_temp - 1;
            FPS_temp = 0;
        }
    });
}

#pragma mark metal
%group metal
%hook CAMetalDrawable

// Fix dispatch queue usage for thread safety
- (void)present {
    %orig;
    frameTick();
}

- (void)presentAfterMinimumDuration:(CFTimeInterval)duration {
    %orig;
    frameTick();
}

- (void)presentAtTime:(CFTimeInterval)presentationTime {
    %orig;
    frameTick();
}
%end //CAMetalDrawable

%hook MTLCommandBuffer
- (void)commit {
    %orig;
    frameTick();
}

// Add additional hooks for more accurate FPS counting
- (void)addCompletedHandler:(void (^)(id))block {
    void (^newBlock)(id) = ^(id buffer) {
        frameTick();
        if (block) block(buffer);
    };
    %orig(newBlock);
}

// Tracking present calls for more accurate counting
- (void)presentDrawable:(id)drawable {
    %orig;
    frameTick();
}

- (void)presentDrawable:(id)drawable atTime:(CFTimeInterval)presentationTime {
    %orig;
    frameTick();
}
%end
%end//metal

// Add UIWindowScene support for Stage Manager
%group scenes
%hook UIWindowScene
- (void)didUpdateCoordinateSpace:(id)space interfaceOrientation:(long long)orientation traitCollection:(id)collection {
    %orig;
    setupFPSWindowForScene(self);
    
    // Update existing windows for this scene
    if ([sceneToWindowMap objectForKey:self]) {
        FPSWindow *window = [sceneToWindowMap objectForKey:self];
        [window updateSceneHandling];
    }
}

- (void)setActivationState:(NSInteger)state {
    %orig;
    
    // Handle scene activation state changes
    if (state == 2) { // UISceneActivationStateForegroundActive = 2
        setupFPSWindowForScene(self);
    } else if (state == 1) { // UISceneActivationStateForegroundInactive = 1
        // When scene becomes inactive, update window visibility
        FPSWindow *window = [sceneToWindowMap objectForKey:self];
        if (window) {
            window.hidden = YES;
        }
    }
}
%end

%hook UISceneDelegate
- (void)windowScene:(UIWindowScene *)windowScene didUpdateCoordinateSpace:(id)space interfaceOrientation:(long long)orientation traitCollection:(id)collection {
    %orig;
    setupFPSWindowForScene(windowScene);
}
%end
%end

%ctor{
    @autoreleasepool {
        NSLog(@"ctor: FPSIndicator");
        
        // Create serial queue for FPS counting and initialize map table only once
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            fpsQueue = dispatch_queue_create("com.fpsindicator.fpsqueue", DISPATCH_QUEUE_SERIAL);
            sceneToWindowMap = [NSMapTable weakToWeakObjectsMapTable];
        });
        
        // Load preferences first before any UI work
        loadPref();
        
        // Initialize window on main thread with delay to ensure proper UIKit initialization
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            setupFPSWindow();
            startRefreshTimer();
            
            // Register for preference changes
            int token = 0;
            notify_register_dispatch("com.fpsindicator/loadPref", &token, dispatch_get_main_queue(), ^(int token) {
                loadPref();
                if (_timer) {
                    updateFPSRefreshRate();
                }
            });
        });
        
        // Initialize hooks
        if (@available(iOS 13.0, *)) {
            %init(scenes);
        }
        %init(ui);
        %init(metal);
    }
}
