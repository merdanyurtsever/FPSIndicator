#import <notify.h>
#import <substrate.h>
#import <objc/runtime.h>

// Import our modular components
#import "Sources/FPSCalculator.h"
#import "Sources/FPSDisplayWindow.h"
#import "Sources/FPSGameSupport.h"

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
    if (!prefs) prefs = [NSMutableDictionary dictionary];
    
    // Cache the preferences for later use
    prefsCache = [prefs mutableCopy];
    
    // Get enabled state with default
    enabled = prefs[@"enabled"] ? [prefs[@"enabled"] boolValue] : YES;
    
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
        
        // Update display
        [[FPSDisplayWindow sharedInstance] updateWithFPS:fps];
        
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
        
        // Initialize core hooks
        %init(metal);
        %init(ui);
        
        // Initialize iOS 13+ scene support if available
        if (@available(iOS 13.0, *)) {
            %init(scenes);
        }
    }
}
