#import <notify.h>
#import <substrate.h>
#import <objc/runtime.h>

// Import our modular components
#import "Sources/FPSCalculator.h"
#import "Sources/FPSDisplayWindow.h"
#import "Sources/FPSGameSupport.h"
#import "Sources/FPSAlternativeOverlay.h"

// Debug flag - enable for verbose logging
#define FPS_DEBUG 1

// Define OpenGL ES silence deprecation warnings before any OpenGL imports
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// Import frameworks
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

// Scene-related data storage (for multiple window/iPad Stage Manager support)
static NSMapTable *sceneToWindowMap;

// Global state for the tweak
static BOOL enabled = YES;
static BOOL isScreenRecording = NO;
static dispatch_source_t fpsDisplayTimer;
static NSMutableDictionary *prefsCache = nil;

/**
 * Loads preferences from the preferences file
 * Updates FPS calculator, display window, and other settings based on user preferences
 */
static void loadPreferences() {
    NSLog(@"FPSIndicator: Loading preferences");
    
    NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
    if (!prefs) {
        NSLog(@"FPSIndicator: No preferences found at path: %@, using defaults", kPrefPath);
        prefs = [NSMutableDictionary dictionary];
    }
    
    // Cache the preferences for later use
    prefsCache = [prefs mutableCopy];
    
    // Get enabled state with default
    enabled = prefs[@"enabled"] ? [prefs[@"enabled"] boolValue] : YES;
    
    if (FPS_DEBUG) {
        NSLog(@"FPSIndicator: Debug - Enabled state: %@", enabled ? @"YES" : @"NO");
        NSLog(@"FPSIndicator: Debug - Bundle ID: %@", [[NSBundle mainBundle] bundleIdentifier]);
    }
    
    // Configure FPS calculation mode
    NSInteger fpsMode = prefs[@"fpsMode"] ? [prefs[@"fpsMode"] intValue] : FPSModeAverage;
    [FPSCalculator sharedInstance].mode = (FPSMode)fpsMode;
    
    // Configure appearance and update display
    dispatch_async(dispatch_get_main_queue(), ^{
        [[FPSDisplayWindow sharedInstance] updateAppearanceWithPreferences:prefs];
        [[FPSDisplayWindow sharedInstance] setVisible:enabled && !isScreenRecording];
    });
}

/**
 * Starts a timer to refresh the FPS display periodically
 * Adaptive to device power mode and user preferences
 */
static void startFPSDisplayTimer() {
    // Cancel existing timer if any
    if (fpsDisplayTimer) {
        dispatch_source_cancel(fpsDisplayTimer);
        fpsDisplayTimer = nil;
    }
    
    // Create a new timer on the main queue
    fpsDisplayTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    
    // Get the optimal refresh interval
    NSTimeInterval interval = [FPSCalculator sharedInstance].fpsUpdateInterval;
    
    // Configure timer parameters
    dispatch_source_set_timer(fpsDisplayTimer, 
                             dispatch_walltime(NULL, 0), 
                             interval * NSEC_PER_SEC, 
                             0);

    // Define what happens on each timer tick
    dispatch_source_set_event_handler(fpsDisplayTimer, ^{
        // Get current FPS value
        double fps = [[FPSCalculator sharedInstance] currentFPS];
        
        // Update display using both methods for maximum compatibility
        [[FPSDisplayWindow sharedInstance] updateWithFPS:fps];
        
        // Also use our CALayer-based alternative method
        [[FPSAlternativeOverlay sharedInstance] showWithFPS:fps];
        
        // Export/log FPS data if enabled
        if (prefsCache && prefsCache[@"enableLogging"] && [prefsCache[@"enableLogging"] boolValue]) {
            static NSString *logPath = nil;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                NSString *docsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
                logPath = [docsDir stringByAppendingPathComponent:@"fps_log.txt"];
            });
            
            if (logPath) {
                [[FPSCalculator sharedInstance] logFPSDataToFile:logPath];
            }
        }
    });
    
    // Start the timer
    dispatch_resume(fpsDisplayTimer);
}

/**
 * Updates the screen recording state and adjusts FPS display visibility
 */
static void handleScreenRecording() {
    if (@available(iOS 11.0, *)) {
        UIScreen *screen = [UIScreen mainScreen];
        isScreenRecording = screen.isCaptured;
        
        // Hide during screen recording if needed
        [[FPSDisplayWindow sharedInstance] setVisible:enabled && !isScreenRecording];
    }
}

#pragma mark - Hooks for various rendering paths

// Metal frame tracking hooks
%group metal
%hook CAMetalDrawable

- (void)present {
    %orig;
    [[FPSCalculator sharedInstance] frameTick];
}

- (void)presentAfterMinimumDuration:(CFTimeInterval)duration {
    %orig;
    [[FPSCalculator sharedInstance] frameTick];
}

- (void)presentAtTime:(CFTimeInterval)presentationTime {
    %orig;
    [[FPSCalculator sharedInstance] frameTick];
}
%end

%hook MTLCommandBuffer
- (void)commit {
    %orig;
    [[FPSCalculator sharedInstance] frameTick];
}

- (void)presentDrawable:(id)drawable {
    %orig;
    [[FPSCalculator sharedInstance] frameTick];
}

- (void)presentDrawable:(id)drawable atTime:(CFTimeInterval)presentationTime {
    %orig;
    [[FPSCalculator sharedInstance] frameTick];
}
%end
%end // metal

// Unity-specific hooks
%group unity
%hook UnityView
- (void)drawRect:(CGRect)rect {
    %orig;
    [[FPSCalculator sharedInstance] frameTick];
}

- (void)displayLinkCallback:(id)sender {
    %orig;
    [[FPSCalculator sharedInstance] frameTick];
}
%end
%end // unity

// Unreal Engine hooks
%group unreal
%hook FIOSView
- (void)drawRect:(CGRect)rect {
    %orig;
    [[FPSCalculator sharedInstance] frameTick];
}

- (void)presentRenderbuffer {
    %orig;
    [[FPSCalculator sharedInstance] frameTick];
}
%end
%end // unreal

// UIKit hooks for general apps
%group ui
%hook UIWindow
- (void)layoutSubviews {
    %orig;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if ([self isKindOfClass:[FPSDisplayWindow class]]) return;
        
        // Initialize based on game support detection
        if ([[FPSGameSupport sharedInstance] isUnityApp]) {
            %init(unity);
        }
        
        if ([[FPSGameSupport sharedInstance] isUnrealApp]) {
            %init(unreal);
        }
        
        // Initialize our FPS display window
        [[FPSDisplayWindow sharedInstance] setVisible:enabled];
        
        // Register for power mode changes
        if (@available(iOS 9.0, *)) {
            [[NSNotificationCenter defaultCenter] addObserver:[FPSCalculator sharedInstance]
                                                     selector:@selector(powerModeDidChange:)
                                                         name:NSProcessInfoPowerStateDidChangeNotification
                                                       object:nil];
            [[FPSCalculator sharedInstance] updatePowerMode];
        }
        
        // Register for screen recording changes
        if (@available(iOS 11.0, *)) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(screenCaptureDidChange:)
                                                         name:UIScreenCapturedDidChangeNotification
                                                       object:nil];
            handleScreenRecording();
        }
        
        // Load preferences and start the display timer
        loadPreferences();
        startFPSDisplayTimer();
    });
}

%new
- (void)screenCaptureDidChange:(NSNotification *)notification {
    handleScreenRecording();
}
%end
%end // ui

// iOS 13+ scene support
%group scenes
%hook UIWindowScene
- (void)didUpdateCoordinateSpace:(id)space interfaceOrientation:(long long)orientation traitCollection:(id)collection {
    %orig;
    
    // Update FPS window frame for the new orientation
    [[FPSDisplayWindow sharedInstance] updateFrameForCurrentOrientation];
}

- (void)setActivationState:(NSInteger)state {
    %orig;
    
    // Handle scene activation/deactivation for iPad Stage Manager
    if (state == 2) { // UISceneActivationStateForegroundActive = 2
        if (@available(iOS 13.0, *)) {
            [[FPSDisplayWindow sharedInstance] setWindowScene:self];
            [[FPSDisplayWindow sharedInstance] updateFrameForCurrentOrientation];
        }
    }
}
%end
%end // scenes

// Core Animation hooks
%group coreanimation
%hook CALayer
- (void)display {
    %orig;
    [[FPSCalculator sharedInstance] frameTick];
}

- (void)setNeedsDisplay {
    %orig;
    // Only count actual redraws, not just marking for redisplay
    if (self.superlayer == nil) {  // Root layer
        [[FPSCalculator sharedInstance] frameTick];
    }
}
%end

%hook CADisplayLink
- (void)addToRunLoop:(NSRunLoop *)runloop forMode:(NSString *)mode {
    %orig;
    if (FPS_DEBUG) {
        NSLog(@"FPSIndicator: DisplayLink added to runloop for %@", mode);
    }
}

- (void)setPaused:(BOOL)paused {
    %orig;
    if (FPS_DEBUG) {
        NSLog(@"FPSIndicator: DisplayLink paused: %@", paused ? @"YES" : @"NO");
    }
}
%end
%end // coreanimation

// OpenGL ES hooks
%group opengl
%hook EAGLContext
- (BOOL)presentRenderbuffer:(NSUInteger)target {
    BOOL result = %orig;
    [[FPSCalculator sharedInstance] frameTick];
    return result;
}
%end
%end // opengl

%ctor {
    @autoreleasepool {
        NSLog(@"FPSIndicator: Initializing");
        
        // Initialize scene table for multiple window support
        sceneToWindowMap = [NSMapTable weakToWeakObjectsMapTable];
        
        // Register to reload preferences when notified
        int token = 0;
        notify_register_dispatch("com.fpsindicator/loadPref", &token, dispatch_get_main_queue(), ^(int token) {
            loadPreferences();
        });
        
        // Initialize core hooks - make sure all rendering paths are covered
        %init(metal);
        %init(ui);
        %init(coreanimation);
        %init(opengl);
        
        // Initialize iOS 13+ scene support if available
        if (@available(iOS 13.0, *)) {
            %init(scenes);
        }
        
        // Note: Unity and Unreal hooks are initialized in the UIWindow hook
        // for proper timing after the app is fully loaded
        
        // Load preferences immediately 
        loadPreferences();
        
        if (FPS_DEBUG) {
            NSLog(@"FPSIndicator: All hooks initialized for bundle: %@", [[NSBundle mainBundle] bundleIdentifier]);
            NSLog(@"FPSIndicator: Window level set to: %f", [[FPSDisplayWindow sharedInstance] windowLevel]);
        }
        
        // Force FPS window creation after a short delay
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[FPSDisplayWindow sharedInstance] makeKeyAndVisible];
            [[FPSDisplayWindow sharedInstance] setVisible:YES];
            
            // Schedule a second attempt to show the FPS window after 3 seconds
            // This helps catch apps that might dismiss or hide overlay windows during startup
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[FPSDisplayWindow sharedInstance] makeKeyAndVisible];
                [[FPSDisplayWindow sharedInstance] setVisible:enabled && !isScreenRecording];
                
                if (FPS_DEBUG) {
                    NSLog(@"FPSIndicator: Second attempt to show window for bundle: %@", 
                          [[NSBundle mainBundle] bundleIdentifier]);
                }
                
                // Start the timer to update the FPS display
                startFPSDisplayTimer();
            });
            
            if (FPS_DEBUG) {
                NSLog(@"FPSIndicator: Window forced to appear for bundle: %@", 
                      [[NSBundle mainBundle] bundleIdentifier]);
            }
        });
    }
}
