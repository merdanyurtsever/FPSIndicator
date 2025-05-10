// Tweak.xm (Revamped)
#import <notify.h>
#import <substrate.h>
#import <objc/runtime.h>

// Import our revamped components with proper headers
#import "Sources/FPSCounter.h"
#import "Sources/FPSDisplay.h"
#import "Sources/FPSPreferences.h"
#import "Sources/FPSGameSupport.h"
#import "Sources/FPSAlternativeOverlay.h"
#import "Sources/FPSPUBGSupport.h"
#import "Sources/FPSLogViewer.h"

// Global state
static BOOL isScreenRecording = NO;
static BOOL isPUBGMobile = NO;
static BOOL usedAlternativeMethod = NO;

/**
 * Loads preferences from the preferences file
 */
static void loadPreferences() {
    NSLog(@"FPSIndicator: Loading preferences");
    [[FPSPreferences sharedPreferences] loadPreferences];
    
    // Check if we're in PUBG Mobile
    isPUBGMobile = [FPSPUBGSupport isPUBGMobile];
    
    // Apply preferences to display
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL shouldDisplay = [[FPSPreferences sharedPreferences] enabled] && 
                            !isScreenRecording &&
                            [[FPSPreferences sharedPreferences] shouldDisplayInApp:
                             [[NSBundle mainBundle] bundleIdentifier]];
        
        if (isPUBGMobile && shouldDisplay) {
            // Use PUBG-specific strategy
            usedAlternativeMethod = YES;
            
            @try {
                // Configure PUBG Support with correct stealth mode
                [[FPSPUBGSupport sharedInstance] setStealthMode:[[FPSPreferences sharedPreferences] pubgStealthMode]];
                [[FPSPUBGSupport sharedInstance] setRefreshRate:[[FPSPreferences sharedPreferences] refreshRate]];
                [[FPSPUBGSupport sharedInstance] setUseQuartzCoreDebug:[[FPSPreferences sharedPreferences] useQuartzDebug]];
                
                // Initialize with safeguards
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    @try {
                        [[FPSPUBGSupport sharedInstance] initialize];
                        [[FPSDisplay sharedInstance] setVisible:NO]; // Hide standard display
                    } @catch (NSException *exception) {
                        NSLog(@"FPSIndicator: Exception initializing PUBG support: %@", exception);
                        
                        // Try to fall back to maximum stealth mode if medium crashes
                        if ([[FPSPreferences sharedPreferences] pubgStealthMode] == 1) {
                            NSLog(@"FPSIndicator: Falling back to maximum stealth mode");
                            [[FPSPUBGSupport sharedInstance] setStealthMode:2]; // Use maximum stealth
                            
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), 
                                          dispatch_get_main_queue(), ^{
                                @try {
                                    [[FPSPUBGSupport sharedInstance] initialize];
                                } @catch (NSException *innerException) {
                                    NSLog(@"FPSIndicator: Fallback also failed: %@", innerException);
                                    // Fall back to normal display if PUBG support fails completely
                                    [[FPSDisplay sharedInstance] setVisible:shouldDisplay];
                                }
                            });
                        } else {
                            // Fall back to normal display if PUBG support fails
                            [[FPSDisplay sharedInstance] setVisible:shouldDisplay];
                        }
                    }
                });
            } @catch (NSException *exception) {
                NSLog(@"FPSIndicator: Critical exception in PUBG support setup: %@", exception);
                // Fall back to normal display if PUBG support fails
                [[FPSDisplay sharedInstance] setVisible:shouldDisplay];
            }
        } else {
            // Use normal strategy
            [[FPSDisplay sharedInstance] setVisible:shouldDisplay];
        }
    });
}

/**
 * Updates the screen recording state and adjusts FPS display visibility
 */
static void handleScreenRecording() {
    if (@available(iOS 11.0, *)) {
        UIScreen *screen = [UIScreen mainScreen];
        isScreenRecording = screen.isCaptured;
        
        // Hide during screen recording if needed
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL shouldDisplay = [[FPSPreferences sharedPreferences] enabled] && 
                                !isScreenRecording &&
                                [[FPSPreferences sharedPreferences] shouldDisplayInApp:
                                 [[NSBundle mainBundle] bundleIdentifier]];
            
            [[FPSDisplay sharedInstance] setVisible:shouldDisplay];
        });
    }
}

// Main app hook for initialization
%group UIApplicationHook
%hook UIApplication

- (BOOL)_shouldStartDisplayLink {
    BOOL result = %orig;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Check if we're in PUBG Mobile
        isPUBGMobile = [FPSPUBGSupport isPUBGMobile];
        
        if (isPUBGMobile) {
            NSLog(@"FPSIndicator: Detected PUBG Mobile, using specialized anti-cheat evasion");
            usedAlternativeMethod = YES;
            
            // Configure PUBG Support with correct stealth mode first
            [[FPSPUBGSupport sharedInstance] setStealthMode:[[FPSPreferences sharedPreferences] pubgStealthMode]];
            [[FPSPUBGSupport sharedInstance] setRefreshRate:[[FPSPreferences sharedPreferences] refreshRate]];
            [[FPSPUBGSupport sharedInstance] setUseQuartzCoreDebug:[[FPSPreferences sharedPreferences] useQuartzDebug]];
            
            // Start with a longer delay to avoid anti-cheat detection
            // Different delay based on stealth mode
            NSInteger delaySeconds = ([[FPSPUBGSupport sharedInstance] stealthMode] == 2) ? 5 : 3;
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delaySeconds * NSEC_PER_SEC)), 
                          dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                @try {
                    [[FPSPUBGSupport sharedInstance] initialize];
                } @catch (NSException *exception) {
                    NSLog(@"FPSIndicator: Failed to initialize PUBG support: %@", exception);
                    
                    // Try to fall back to maximum stealth mode if medium crashes
                    if ([[FPSPreferences sharedPreferences] pubgStealthMode] == 1) {
                        NSLog(@"FPSIndicator: Falling back to maximum stealth mode");
                        [[FPSPUBGSupport sharedInstance] setStealthMode:2]; // Use maximum stealth
                        
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), 
                                      dispatch_get_main_queue(), ^{
                            @try {
                                [[FPSPUBGSupport sharedInstance] initialize];
                            } @catch (NSException *innerException) {
                                NSLog(@"FPSIndicator: Fallback also failed: %@", innerException);
                            }
                        });
                    }
                }
            });
        } else {
            // Standard initialization for normal apps
            [[FPSCounter sharedInstance] start];
            
            // Initialize the display window
            dispatch_async(dispatch_get_main_queue(), ^{
                [[FPSDisplay sharedInstance] makeKeyAndVisible];
                loadPreferences();
            });
        }
        
        // Register for screen recording changes
        if (@available(iOS 11.0, *)) {
            [[NSNotificationCenter defaultCenter] addObserver:[FPSDisplay sharedInstance]
                                                     selector:@selector(screenCaptureDidChange:)
                                                         name:UIScreenCapturedDidChangeNotification
                                                       object:nil];
            handleScreenRecording();
        }
    });
    
    return result;
}

%end
%end

// iOS 13+ scene support
%group SceneSupport
%hook UIWindowScene

- (void)_didActivate {
    %orig;
    
    if (@available(iOS 13.0, *)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[FPSDisplay sharedInstance] setupWithWindowScene:self];
        });
    }
}

%end
%end

%ctor {
    @autoreleasepool {
        NSLog(@"FPSIndicator: Initializing (Revamped Version)");
        
        // Check if we're in PUBG Mobile
        BOOL isInPUBG = [FPSPUBGSupport isPUBGMobile];
        
        if (isInPUBG) {
            NSLog(@"FPSIndicator: PUBG Mobile detected at launch, using anti-cheat evasion strategy");
            isPUBGMobile = YES;
            
            // We'll delay our actual initialization to avoid early anti-cheat detection
            // This is handled in the UIApplication hook above
        }
        
        // Register to reload preferences when notified
        int token = 0;
        notify_register_dispatch("com.fpsindicator/loadPref", &token, dispatch_get_main_queue(), ^(int token) {
            loadPreferences();
        });
        
        // Register notification to open log files
        int logFileToken = 0;
        notify_register_dispatch("com.fpsindicator/openLogFile", &logFileToken, dispatch_get_main_queue(), ^(int token) {
            NSString *encodedPath = [[NSUserDefaults standardUserDefaults] objectForKey:@"com.fpsindicator.lastLogPath"];
            if (encodedPath) {
                NSString *logFilePath = [encodedPath stringByRemovingPercentEncoding];
                
                // Check if the file exists
                if ([[NSFileManager defaultManager] fileExistsAtPath:logFilePath]) {
                    // Use UIDocumentInteractionController to view the file
                    NSURL *fileURL = [NSURL fileURLWithPath:logFilePath];
                    UIDocumentInteractionController *docController = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
                    
                    // Find the key window to present from
                    UIWindow *keyWindow = nil;
                    if (@available(iOS 13.0, *)) {
                        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                            if (scene.activationState == UISceneActivationStateForegroundActive) {
                                for (UIWindow *window in scene.windows) {
                                    if (window.isKeyWindow) {
                                        keyWindow = window;
                                        break;
                                    }
                                }
                                if (keyWindow) break;
                            }
                        }
                    } else {
                        #pragma clang diagnostic push
                        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
                        keyWindow = [UIApplication sharedApplication].keyWindow;
                        #pragma clang diagnostic pop
                    }
                    
                    if (keyWindow && keyWindow.rootViewController) {
                        UIViewController *rootVC = keyWindow.rootViewController;
                        // Navigate to the presented view controller if available
                        while (rootVC.presentedViewController) {
                            rootVC = rootVC.presentedViewController;
                        }
                        
                        docController.delegate = (id<UIDocumentInteractionControllerDelegate>)rootVC;
                        [docController presentOptionsMenuFromRect:rootVC.view.bounds inView:rootVC.view animated:YES];
                    }
                }
            }
        });
        
        // Initialize our hooks
        %init(UIApplicationHook);
        
        // Initialize iOS 13+ scene support if available
        if (@available(iOS 13.0, *)) {
            %init(SceneSupport);
        }
        
        // Load preferences immediately but don't show the display yet
        // (will be handled by UIApplication hook)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            loadPreferences();
        });
    }
}
