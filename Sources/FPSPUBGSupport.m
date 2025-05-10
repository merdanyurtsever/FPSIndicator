#import "FPSPUBGSupport.h"
#import "FPSAlternativeOverlay.h"
#import <dlfcn.h>
#import <mach/mach_time.h>
#import <objc/runtime.h>

// Private QuartzCore debug API declarations
// These are only available with appropriate entitlements
typedef double (*CARenderServerGetDebugValueFuncPtr)(int);
static CARenderServerGetDebugValueFuncPtr CARenderServerGetDebugValue = NULL;

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
        
        // Default settings
        _stealthMode = 1; // Medium stealth by default
        _useQuartzCoreDebug = NO; // Off by default, requires special entitlements
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
    // Determine if we can use the QuartzCore debug API
    if (_useQuartzCoreDebug) {
        [self tryLoadQuartzCoreDebugAPI];
    }
    
    // Create a delayed setup to avoid early detection
    // Anti-cheat often scans early in the app lifecycle
    CGFloat delay = (_stealthMode == 2) ? 10.0 : 5.0;
    
    _delayedSetupTimer = [NSTimer scheduledTimerWithTimeInterval:delay 
                                                         target:self 
                                                       selector:@selector(delayedSetup) 
                                                       userInfo:nil 
                                                        repeats:NO];
}

- (void)delayedSetup {
    NSLog(@"FPSIndicator: Performing delayed PUBG setup with stealth mode %ld", (long)_stealthMode);
    
    // Choose the appropriate method based on stealth mode
    switch (_stealthMode) {
        case 0: // Normal mode
            [self setupStandardMonitoring];
            break;
            
        case 1: // Medium stealth
            [self setupStealthMonitoring];
            break;
            
        case 2: // Maximum stealth
            [self setupMaximumStealthMonitoring];
            break;
            
        default:
            [self setupStealthMonitoring]; // Default to medium stealth
            break;
    }
}

#pragma mark - Monitoring Methods

- (void)startMonitoring {
    if (_displayLink == nil) {
        [self setupStealthMonitoring]; // Default to stealth monitoring
    }
}

- (void)stopMonitoring {
    [_displayLink invalidate];
    _displayLink = nil;
    
    if (_hooked) {
        [self removeMetalHooks];
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
    } else {
        NSLog(@"FPSIndicator: Failed to load QuartzCore framework");
    }
}

- (double)getFPSFromQuartzCore {
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
    [_displayLink invalidate];
    
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkFired:)];
    if (@available(iOS 10.0, *)) {
        _displayLink.preferredFramesPerSecond = (NSInteger)_refreshRate; // Very low refresh rate
    } else {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        _displayLink.frameInterval = 60 / (NSInteger)_refreshRate;
        #pragma clang diagnostic pop
    }
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    
    NSLog(@"FPSIndicator: Started stealth FPS monitoring at %.1f Hz", _refreshRate);
}

// Maximum stealth - minimal footprint but less accurate
- (void)setupMaximumStealthMonitoring {
    // Use a background thread timer instead of CADisplayLink
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [NSTimer scheduledTimerWithTimeInterval:1.0 / self->_refreshRate 
                                        target:self 
                                      selector:@selector(backgroundTimerFired) 
                                      userInfo:nil 
                                       repeats:YES];
        
        // Create a background runloop to keep timer firing
        [[NSRunLoop currentRunLoop] run];
    });
    
    NSLog(@"FPSIndicator: Started maximum stealth FPS monitoring");
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
    _frameCount++;
    
    // Calculate FPS approximately once per second
    if (link.timestamp - _lastFPSCalculationTime >= 1.0) {
        _currentFPS = _frameCount / (link.timestamp - _lastFPSCalculationTime);
        _frameCount = 0;
        _lastFPSCalculationTime = link.timestamp;
        
        // If we have QuartzCore debug API access, use it instead
        if (CARenderServerGetDebugValue) {
            _currentFPS = [self getFPSFromQuartzCore];
        }
        
        // Update the display
        [[FPSAlternativeOverlay sharedInstance] showWithFPS:_currentFPS];
    }
}

- (void)backgroundTimerFired {
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
    
    if (smoothedFPS == 0) {
        smoothedFPS = instantFPS;
    } else {
        smoothedFPS = smoothedFPS * 0.9 + instantFPS * 0.1;
    }
    
    _currentFPS = smoothedFPS;
    
    // Update the display on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        [[FPSAlternativeOverlay sharedInstance] showWithFPS:self->_currentFPS];
    });
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
