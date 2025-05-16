#import "FPSPUBGSupport.h"
#import "FPSAlternativeOverlay.h"
#import "FPSPUBGUIIntegration.h"
#import <dlfcn.h>
#import <mach/mach_time.h>
#import <objc/runtime.h>

// Private QuartzCore debug API declarations
// These are only available with appropriate entitlements
typedef double (*CARenderServerGetDebugValueFuncPtr)(int);
static CARenderServerGetDebugValueFuncPtr CARenderServerGetDebugValue = NULL;

// CoreAnimation Performance HUD Module API declarations
typedef void* (*CAPerfHUDModuleCreateFuncPtr)(void);
typedef double (*CAPerfHUDGetValueFuncPtr)(void* module, int index);

static CAPerfHUDModuleCreateFuncPtr CAPerfHUDModuleCreate = NULL;
static CAPerfHUDGetValueFuncPtr CAPerfHUDGetValue = NULL;
static void* CAHUDModule = NULL;

@implementation FPSPUBGSupport {
    CADisplayLink *_displayLink;
    NSTimeInterval _lastTimestamp;
    NSMutableArray<NSNumber *> *_frameTimestamps;
    
    // For FPS calculation
    NSInteger _frameCount;
    NSTimeInterval _lastFPSCalculationTime;
    double _currentFPS;
    
    // For Metal hooking
    void *_metalLib;
    IMP _originalPresentDrawable;
    BOOL _hooked;
    
    // For delayed setup
    NSTimer *_delayedSetupTimer;
    
    // For CA Perf HUD tracking
    BOOL _caHUDInitialized;
}

#pragma mark - Lifecycle

+ (instancetype)sharedInstance {
    static FPSPUBGSupport *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _frameTimestamps = [NSMutableArray array];
        _lastTimestamp = 0;
        _frameCount = 0;
        _lastFPSCalculationTime = 0;
        _currentFPS = 0;
        _hooked = NO;
        _caHUDInitialized = NO;
        
        // Default settings
        _stealthMode = 1; // Medium stealth by default
        _pubgUiMode = 0; // Standard display by default
        _useQuartzCoreDebug = NO; // Off by default, requires special entitlements
        _useCoreAnimationPerfHUD = YES; // On by default, more reliable than QuartzCore debug
        _refreshRate = 2.0; // 2Hz refresh rate by default for PUBG
    }
    return self;
}

#pragma mark - PUBG Mobile Detection

+ (BOOL)isPUBGMobile {
    NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;
    
    // List of known PUBG Mobile bundle IDs
    NSArray<NSString *> *pubgBundleIDs = @[
        @"com.tencent.ig", // Global version
        @"com.pubg.krmobile", // Korean version
        @"com.tencent.tmgp.pubgmhd", // Chinese version
        @"com.rekoo.pubgm", // Taiwan version
        @"com.vng.pubgmobile" // Vietnam version
    ];
    
    return [pubgBundleIDs containsObject:bundleID];
}

#pragma mark - Initialization

- (void)initialize {
    // Add safeguards to make sure the tweak doesn't crash PUBG
    @try {
        // Always try to initialize the QuartzCore debug API and CA Perf HUD
        // This gives us the most accurate FPS data directly from CoreAnimation
        if (_useQuartzCoreDebug || _useCoreAnimationPerfHUD) {
            [self tryLoadQuartzCoreDebugAPI];
        }
        
        // Setup the UI integration based on pubgUiMode
        if (_pubgUiMode > 0) {
            NSLog(@"FPSIndicator: Initializing PUBG UI integration with mode %ld", (long)_pubgUiMode);
            [[FPSPUBGUIIntegration sharedInstance] initializeWithMode:_pubgUiMode];
        }
        
        // Create a delayed setup to avoid early detection
        // Anti-cheat often scans early in the app lifecycle
        // Use longer delays for higher stealth modes
        CGFloat delay = (_stealthMode == 2) ? 10.0 : 
                        (_stealthMode == 1) ? 7.0 : 5.0;
        
        // Use a dispatch_after instead of NSTimer for better reliability
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), 
                      dispatch_get_main_queue(), ^{
            [self delayedSetup];
        });
    } @catch (NSException *exception) {
        NSLog(@"FPSIndicator: Exception during PUBG support initialization: %@", exception);
    }
}

- (void)delayedSetup {
    NSLog(@"FPSIndicator: Performing delayed PUBG setup with stealth mode %ld", (long)_stealthMode);
    
    @try {
        // For medium stealth mode which is prone to crashing, 
        // add extra delay to ensure PUBG is fully initialized
        if (_stealthMode == 1) {
            // Add an extra delay for medium stealth mode to avoid crashes
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), 
                          dispatch_get_main_queue(), ^{
                [self setupSafeMediumStealth];
                
                // Start the UI integration if applicable
                if (self->_pubgUiMode > 0) {
                    [[FPSPUBGUIIntegration sharedInstance] startDisplayingWithInitialFPS:0.0];
                }
            });
            return;
        }
        
        // For other modes, proceed normally
        // Choose the appropriate method based on stealth mode
        switch (_stealthMode) {
            case 0: // Normal mode
                [self setupStandardMonitoring];
                break;
                
            case 1: // Medium stealth - already handled above
                break;
                
            case 2: // Maximum stealth
                [self setupMaximumStealthMonitoring];
                break;
                
            default:
                [self setupMaximumStealthMonitoring]; // Default to maximum stealth
                break;
        }
        
        // Start the UI integration if applicable
        if (_pubgUiMode > 0) {
            [[FPSPUBGUIIntegration sharedInstance] startDisplayingWithInitialFPS:0.0];
        }
    } @catch (NSException *exception) {
        NSLog(@"FPSIndicator: Exception during PUBG delayed setup: %@", exception);
        
        // Fall back to maximum stealth mode if any other mode causes issues
        @try {
            [self setupMaximumStealthMonitoring];
            
            // Still try to start UI integration in fallback mode
            if (_pubgUiMode > 0) {
                [[FPSPUBGUIIntegration sharedInstance] startDisplayingWithInitialFPS:0.0];
            }
        } @catch (NSException *innerException) {
            NSLog(@"FPSIndicator: Failed to fall back to maximum stealth mode: %@", innerException);
        }
    }
}

#pragma mark - Monitoring Methods

- (void)startMonitoring {
    if (_displayLink == nil) {
        if (_stealthMode == 1) {
            [self setupSafeMediumStealth]; 
        } else {
            [self setupStealthMonitoring]; // Default to stealth monitoring
        }
    }
}

// New safer implementation for medium stealth mode
- (void)setupSafeMediumStealth {
    @try {
        // First, ensure any existing displays are cleared
        [_displayLink invalidate];
        _displayLink = nil;
        
        // Check if PUBG is fully initialized
        // We'll add a few safety checks to ensure the app is ready
        UIWindow *keyWindow = nil;
        
        // Try different approaches to find a window in a safe way
        if (@available(iOS 13.0, *)) {
            // Modern approach for iOS 13+
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow *window in scene.windows) {
                        if (window.isKeyWindow) {
                            keyWindow = window;
                            break;
                        }
                    }
                    if (!keyWindow && scene.windows.count > 0) {
                        keyWindow = scene.windows.firstObject;
                    }
                    break;
                }
            }
        } else {
            // Legacy approach
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            keyWindow = [UIApplication sharedApplication].keyWindow;
            #pragma clang diagnostic pop
        }
        
        // If we don't have a key window, app might not be fully initialized yet
        if (!keyWindow) {
            NSLog(@"FPSIndicator: No key window found yet, delaying initialization further");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), 
                          dispatch_get_main_queue(), ^{
                [self setupSafeMediumStealth];
            });
            return;
        }
        
        // Only proceed if we can verify the app is in a good state
        NSLog(@"FPSIndicator: App appears ready, proceeding with safe medium stealth setup");
        
        // First try to use the CA Performance HUD if available
        if (_useQuartzCoreDebug) {
            [self tryLoadQuartzCoreDebugAPI];
            
            // If we have Core Animation Performance HUD working, use timer-based approach
            // instead of display link to minimize anti-cheat detection
            if (_caHUDInitialized || CARenderServerGetDebugValue) {
                NSLog(@"FPSIndicator: Using QuartzCore API for FPS tracking with timer-based updates");
                [self setupHUDBasedTimerMonitoring];
                return;
            }
        }
        
        // Fall back to display link method if CoreAnimation HUD isn't available
        // Create a display link with careful error handling
        dispatch_async(dispatch_get_main_queue(), ^{
            @try {
                // Use lower priority queue for creating the display link to avoid interfering with game's main thread
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                    @try {
                        CADisplayLink *link = [CADisplayLink displayLinkWithTarget:self selector:@selector(safeMediumStealthCallback:)];
                        
                        // Set a very conservative refresh rate to minimize impact
                        if (@available(iOS 10.0, *)) {
                            link.preferredFramesPerSecond = 2; // Very low rate - 2 updates per second
                        } else {
                            #pragma clang diagnostic push
                            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
                            link.frameInterval = 30; // Every 30 frames (1-2 times per second at 60fps)
                            #pragma clang diagnostic pop
                        }
                        
                        // Use a safer run loop mode for games
                        [link addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
                        
                        self->_displayLink = link;
                        
                        NSLog(@"FPSIndicator: Successfully created safe display link");
                        
                        // Run the current run loop briefly to ensure link is properly established
                        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
                    } @catch (NSException *exception) {
                        NSLog(@"FPSIndicator: Exception creating display link: %@", exception);
                        [self fallbackToTimer];
                    }
                });
            } @catch (NSException *exception) {
                NSLog(@"FPSIndicator: Exception in display link setup: %@", exception);
                [self fallbackToTimer];
            }
        });
        
        // Initialize overlay with zero
        dispatch_async(dispatch_get_main_queue(), ^{
            [[FPSAlternativeOverlay sharedInstance] showWithFPS:0.0];
        });
    } @catch (NSException *exception) {
        NSLog(@"FPSIndicator: Critical exception in setupSafeMediumStealth: %@", exception);
        // If all else fails, fall back to the maximum stealth mode
        [self setupMaximumStealthMonitoring];
    }
}

- (void)safeMediumStealthCallback:(CADisplayLink *)link {
    @try {
        // This is a safer callback that does minimal work
        static NSInteger frameCounter = 0;
        static CFTimeInterval lastTimestamp = 0;
        
        // Initialize on first call
        if (lastTimestamp == 0) {
            lastTimestamp = link.timestamp;
            return;
        }
        
        frameCounter++;
        
        // Only update FPS occasionally to minimize overhead
        if (frameCounter % 30 == 0) {
            CFTimeInterval delta = link.timestamp - lastTimestamp;
            double fps = frameCounter / delta;
            
            lastTimestamp = link.timestamp;
            frameCounter = 0;
            
            _currentFPS = fps;
            
            // Update UI based on selected mode
            if (_pubgUiMode > 0) {
                // Use our new UI integration approach
                [[FPSPUBGUIIntegration sharedInstance] updateWithFPS:_currentFPS];
            } else {
                // Use the traditional approach
                dispatch_async(dispatch_get_main_queue(), ^{
                    @try {
                        [[FPSAlternativeOverlay sharedInstance] showWithFPS:self->_currentFPS];
                    } @catch (NSException *exception) {
                        NSLog(@"FPSIndicator: Exception updating UI: %@", exception);
                    }
                });
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"FPSIndicator: Exception in safe callback: %@", exception);
    }
}

- (void)fallbackToTimer {
    NSLog(@"FPSIndicator: Falling back to timer-based approach");
    [self setupMaximumStealthMonitoring];
}

- (void)stopMonitoring {
    [_displayLink invalidate];
    _displayLink = nil;
    
    if (_hooked) {
        [self removeMetalHooks];
    }
    
    // Stop the UI integration if applicable
    if (_pubgUiMode > 0) {
        [[FPSPUBGUIIntegration sharedInstance] stopDisplaying];
    }
}

- (double)getCurrentFPS {
    return _currentFPS;
}

#pragma mark - QuartzCore Debug API

- (void)tryLoadQuartzCoreDebugAPI {
    // This requires appropriate entitlements to work
    // (com.apple.QuartzCore.debug entitlement)
    void *quartzCore = dlopen("/System/Library/Frameworks/QuartzCore.framework/QuartzCore", RTLD_NOW);
    if (quartzCore) {
        CARenderServerGetDebugValue = (CARenderServerGetDebugValueFuncPtr)dlsym(quartzCore, "CARenderServerGetDebugValue");
        
        if (CARenderServerGetDebugValue) {
            NSLog(@"FPSIndicator: Successfully loaded QuartzCore debug API");
        } else {
            NSLog(@"FPSIndicator: Failed to load CARenderServerGetDebugValue function");
        }
        
        // Try to load CoreAnimation Performance HUD Module
        if (_useCoreAnimationPerfHUD) {
            [self tryLoadCAPerfHUDModule:quartzCore];
        }
    } else {
        NSLog(@"FPSIndicator: Failed to load QuartzCore framework");
    }
}

- (void)tryLoadCAPerfHUDModule:(void*)quartzCore {
    @try {
        // First attempt - try to load the newer CoreAnimation Performance HUD Module API
        CAPerfHUDModuleCreate = (CAPerfHUDModuleCreateFuncPtr)dlsym(quartzCore, "CAPerfHUDModuleCreate");
        CAPerfHUDGetValue = (CAPerfHUDGetValueFuncPtr)dlsym(quartzCore, "CAPerfHUDGetValue");
        
        if (CAPerfHUDModuleCreate && CAPerfHUDGetValue) {
            CAHUDModule = CAPerfHUDModuleCreate();
            if (CAHUDModule) {
                _caHUDInitialized = YES;
                NSLog(@"FPSIndicator: Successfully initialized CA Performance HUD Module");
                return;
            }
        }
        
        // Second attempt - try alternate symbol names that might be used
        CAPerfHUDModuleCreate = (CAPerfHUDModuleCreateFuncPtr)dlsym(quartzCore, "_CAPerfHUDModuleCreate");
        CAPerfHUDGetValue = (CAPerfHUDGetValueFuncPtr)dlsym(quartzCore, "_CAPerfHUDGetValue");
        
        if (CAPerfHUDModuleCreate && CAPerfHUDGetValue) {
            CAHUDModule = CAPerfHUDModuleCreate();
            if (CAHUDModule) {
                _caHUDInitialized = YES;
                NSLog(@"FPSIndicator: Successfully initialized CA Performance HUD Module (alternate symbols)");
                return;
            }
        }
        
        NSLog(@"FPSIndicator: Failed to initialize CA Performance HUD Module");
    } @catch (NSException *exception) {
        NSLog(@"FPSIndicator: Exception loading CA Performance HUD Module: %@", exception);
    }
}

- (double)getFPSFromQuartzCore {
    // First try the CA Performance HUD Module if available
    if (_caHUDInitialized && CAHUDModule && CAPerfHUDGetValue) {
        @try {
            // Try index 0, 1, and 2 which typically contain FPS information
            double fps = CAPerfHUDGetValue(CAHUDModule, 1);
            if (fps > 0 && fps <= 120) {
                return fps;
            }
            
            // If first index didn't work, try alternate indices
            for (int i = 0; i < 5; i++) {
                fps = CAPerfHUDGetValue(CAHUDModule, i);
                if (fps > 0 && fps <= 120) {
                    return fps;
                }
            }
        } @catch (NSException *exception) {
            NSLog(@"FPSIndicator: Exception getting FPS from CA Perf HUD: %@", exception);
        }
    }
    
    // Fall back to original method if CA Performance HUD not available
    if (CARenderServerGetDebugValue) {
        // FPS is at index 5 in the debug values array
        return CARenderServerGetDebugValue(5);
    }
    
    return 0;
}

#pragma mark - Monitoring Implementations

// Standard monitoring - not recommended for PUBG due to anti-cheat
- (void)setupStandardMonitoring {
    [_displayLink invalidate];
    
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkFired:)];
    if (@available(iOS 10.0, *)) {
        _displayLink.preferredFramesPerSecond = 30; // Poll at approximately half the max framerate
    } else {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        _displayLink.frameInterval = 2;
        #pragma clang diagnostic pop
    }
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    
    NSLog(@"FPSIndicator: Started standard FPS monitoring");
}

// Stealth monitoring - better for avoiding detection
- (void)setupStealthMonitoring {
    @try {
        [_displayLink invalidate];
        _displayLink = nil;
        
        // Use dispatch_async to ensure we're on the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            @try {
                self->_displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkFired:)];
                
                // Set a safe refresh rate (no faster than 5Hz for medium stealth)
                CGFloat safeRate = MAX(1.0, MIN(5.0, self->_refreshRate));
                
                if (@available(iOS 10.0, *)) {
                    self->_displayLink.preferredFramesPerSecond = (NSInteger)safeRate;
                } else {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
                    self->_displayLink.frameInterval = 60 / (NSInteger)safeRate;
                    #pragma clang diagnostic pop
                }
                
                [self->_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
                
                NSLog(@"FPSIndicator: Started stealth FPS monitoring at %.1f Hz", safeRate);
                
                // Initialize the display with 0 FPS
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[FPSAlternativeOverlay sharedInstance] showWithFPS:0.0];
                });
            } @catch (NSException *exception) {
                NSLog(@"FPSIndicator: Exception setting up stealth monitoring: %@", exception);
            }
        });
    } @catch (NSException *exception) {
        NSLog(@"FPSIndicator: Exception invalidating display link: %@", exception);
    }
}

// Maximum stealth - minimal footprint but less accurate
- (void)setupMaximumStealthMonitoring {
    // Clear any existing timers to prevent duplicates
    [_displayLink invalidate];
    _displayLink = nil;
    
    // Use a simple counter approach with no hooks
    // This is the safest option for avoiding anti-cheat detection
    
    __weak typeof(self) weakSelf = self;
    
    // Use GCD timer instead of NSTimer for better reliability
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
    if (timer) {
        // Set timer parameters (1/2 second interval)
        uint64_t interval = 500 * NSEC_PER_MSEC;
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, interval), interval, 100 * NSEC_PER_MSEC);
        
        // Set event handler
        dispatch_source_set_event_handler(timer, ^{
            typeof(self) strongSelf = weakSelf;
            if (strongSelf) {
                @try {
                    [strongSelf backgroundTimerFired];
                } @catch (NSException *exception) {
                    NSLog(@"FPSIndicator: Exception in maximum stealth timer: %@", exception);
                }
            }
        });
        
        // Start the timer
        dispatch_resume(timer);
        
        // Store timer reference (using associated objects or other pattern would be better in a real implementation)
        NSLog(@"FPSIndicator: Started maximum stealth FPS monitoring using GCD timer");
        
        // Initialize the display with 0 FPS
        dispatch_async(dispatch_get_main_queue(), ^{
            [[FPSAlternativeOverlay sharedInstance] showWithFPS:0.0];
        });
    } else {
        NSLog(@"FPSIndicator: Failed to create GCD timer for maximum stealth monitoring");
    }
}

- (void)setupHUDBasedTimerMonitoring {
    // Clear any existing timers to prevent duplicates
    [_displayLink invalidate];
    _displayLink = nil;
    
    // This is a safer alternative that uses a timer instead of a display link
    // Combined with the CoreAnimation HUD, it's less likely to be detected
    
    __weak typeof(self) weakSelf = self;
    
    // Use GCD timer - more reliable than NSTimer
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, 
                                                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
    if (timer) {
        // Set timer parameters - use refresh rate but no faster than 5Hz to avoid detection
        CGFloat safeRate = MAX(1.0, MIN(5.0, _refreshRate));
        uint64_t interval = (uint64_t)(1.0 / safeRate * NSEC_PER_SEC);
        
        dispatch_source_set_timer(timer, 
                                dispatch_time(DISPATCH_TIME_NOW, interval), 
                                interval, 
                                100 * NSEC_PER_MSEC);
        
        // Set event handler
        dispatch_source_set_event_handler(timer, ^{
            typeof(self) strongSelf = weakSelf;
            if (strongSelf) {
                @try {
                    // Get FPS directly from CoreAnimation HUD
                    double fps = [strongSelf getFPSFromQuartzCore];
                    
                    // Apply smoothing to avoid jumpy values
                    static double smoothedFPS = 0;
                    if (smoothedFPS == 0) {
                        smoothedFPS = fps;
                    } else {
                        smoothedFPS = smoothedFPS * 0.7 + fps * 0.3;
                    }
                    
                    // Only update if we got a valid value
                    if (fps > 0) {
                        strongSelf->_currentFPS = smoothedFPS;
                        
                        // Update UI based on the selected mode
                        if (strongSelf->_pubgUiMode > 0) {
                            [[FPSPUBGUIIntegration sharedInstance] updateWithFPS:strongSelf->_currentFPS];
                        } else {
                            // Use the traditional approach
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [[FPSAlternativeOverlay sharedInstance] showWithFPS:strongSelf->_currentFPS];
                            });
                        }
                    }
                } @catch (NSException *exception) {
                    NSLog(@"FPSIndicator: Exception in HUD timer handler: %@", exception);
                }
            }
        });
        
        // Start the timer
        dispatch_resume(timer);
        
        NSLog(@"FPSIndicator: Started CoreAnimation HUD-based FPS monitoring at %.1f Hz", safeRate);
        
        // Initialize display with 0 FPS
        dispatch_async(dispatch_get_main_queue(), ^{
            [[FPSAlternativeOverlay sharedInstance] showWithFPS:0.0];
        });
    } else {
        NSLog(@"FPSIndicator: Failed to create GCD timer for HUD monitoring, falling back to alternative method");
        [self setupMaximumStealthMonitoring];
    }
}

#pragma mark - Callback Methods

- (void)displayLinkFired:(CADisplayLink *)link {
    // For the first time
    if (_lastTimestamp == 0) {
        _lastTimestamp = link.timestamp;
        _lastFPSCalculationTime = link.timestamp;
        return;
    }
    
    // Calculate frame time and add to rolling buffer
    NSTimeInterval frameTime = link.timestamp - _lastTimestamp;
    _lastTimestamp = link.timestamp;
    
    [_frameTimestamps addObject:@(frameTime)];
    
    // Keep our buffer at a reasonable size
    while (_frameTimestamps.count > 60) {
        [_frameTimestamps removeObjectAtIndex:0];
    }
    
    // Update FPS calculation
    _frameCount++;        // Calculate FPS approximately once per second
    if (link.timestamp - _lastFPSCalculationTime >= 1.0) {
        _currentFPS = _frameCount / (link.timestamp - _lastFPSCalculationTime);
        _frameCount = 0;
        _lastFPSCalculationTime = link.timestamp;
        
        // If we have QuartzCore debug API access, use it instead
        if (CARenderServerGetDebugValue) {
            _currentFPS = [self getFPSFromQuartzCore];
        }
        
        // Update UI based on the selected mode
        if (_pubgUiMode > 0) {
            // Use our new UI integration approach
            [[FPSPUBGUIIntegration sharedInstance] updateWithFPS:_currentFPS];
        } else {
            // Use the traditional approach
            dispatch_async(dispatch_get_main_queue(), ^{
                [[FPSAlternativeOverlay sharedInstance] showWithFPS:self->_currentFPS];
            });
        }
    }
}

- (void)backgroundTimerFired {
    @try {
        // This is a simpler method that just calculates based on mach_absolute_time()
        static uint64_t lastTime = 0;
        static double machTimebase = 0;
        
        if (machTimebase == 0) {
            mach_timebase_info_data_t timebase;
            mach_timebase_info(&timebase);
            machTimebase = (double)timebase.numer / (double)timebase.denom;
        }
        
        uint64_t currentTime = mach_absolute_time();
        
        if (lastTime == 0) {
            lastTime = currentTime;
            return;
        }
        
        // Calculate frame time
        double deltaTime = (currentTime - lastTime) * machTimebase / NSEC_PER_SEC;
        lastTime = currentTime;
        
        // Estimate FPS (this is less accurate but very low profile)
        // We use an exponential moving average to smooth values
        static double smoothedFPS = 0;
        double instantFPS = 1.0 / deltaTime;
        
        // Clamp to reasonable values to avoid spikes
        instantFPS = MAX(0.0, MIN(instantFPS, 120.0));
        
        if (smoothedFPS == 0) {
            smoothedFPS = instantFPS;
        } else {
            smoothedFPS = smoothedFPS * 0.9 + instantFPS * 0.1;
        }
        
        _currentFPS = smoothedFPS;
        
        // Update UI based on selected mode
        if (_pubgUiMode > 0) {
            // Use our new UI integration approach
            [[FPSPUBGUIIntegration sharedInstance] updateWithFPS:_currentFPS];
        } else {
            // Use the traditional approach
            dispatch_async(dispatch_get_main_queue(), ^{
                [[FPSAlternativeOverlay sharedInstance] showWithFPS:self->_currentFPS];
            });
        }
    } @catch (NSException *exception) {
        NSLog(@"FPSIndicator: Exception in backgroundTimerFired: %@", exception);
    }
}

#pragma mark - Metal Hooking (Advanced)

- (void)setupMetalHooks {
    // Metal hooking is a more advanced technique
    // Intentionally not implemented here to avoid anti-cheat issues
    // This would involve swizzling Metal presentation methods
    NSLog(@"FPSIndicator: Metal hooks not implemented for anti-cheat safety");
}

- (void)removeMetalHooks {
    // Would remove any Metal hooks if implemented
}

@end
