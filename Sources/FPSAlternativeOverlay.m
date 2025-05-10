#import "FPSAlternativeOverlay.h"
#import <QuartzCore/QuartzCore.h>

@implementation FPSAlternativeOverlay {
    CATextLayer *_fpsTextLayer;
    CALayer *_backgroundLayer;
    BOOL _isVisible;
}

+ (instancetype)sharedInstance {
    static FPSAlternativeOverlay *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        // Create layers
        _backgroundLayer = [CALayer layer];
        _backgroundLayer.cornerRadius = 5.0;
        _backgroundLayer.borderWidth = 1.0;
        _backgroundLayer.borderColor = [UIColor blackColor].CGColor;
        _backgroundLayer.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8].CGColor;
        _backgroundLayer.frame = CGRectMake(0, 0, 80, 30);
        
        // Position in top right by default
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        CGFloat rightEdge = screenWidth - 10 - 80;
        CGFloat topEdge = 40; // Account for status bar
        
        _backgroundLayer.position = CGPointMake(rightEdge + 40, topEdge + 15);
        
        // Add text layer
        _fpsTextLayer = [CATextLayer layer];
        _fpsTextLayer.frame = CGRectMake(5, 5, 70, 20);
        _fpsTextLayer.fontSize = 14.0;
        _fpsTextLayer.alignmentMode = kCAAlignmentCenter;
        _fpsTextLayer.string = @"-- FPS";
        _fpsTextLayer.foregroundColor = [UIColor greenColor].CGColor;
        _fpsTextLayer.contentsScale = [UIScreen mainScreen].scale;
        
        [_backgroundLayer addSublayer:_fpsTextLayer];
        
        _isVisible = NO;
    }
    return self;
}

- (void)showWithFPS:(double)fps {
    // Ensure we're on the main thread
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showWithFPS:fps];
        });
        return;
    }
    
    // Update FPS value first, even if not yet visible
    [self updateWithFPS:fps];
    
    // If already visible, nothing else to do
    if (_isVisible && _backgroundLayer.superlayer != nil) {
        return;
    }
    
    // Try to display the overlay with multiple fallback methods
    [self safelyAttachOverlay];
}

- (void)safelyAttachOverlay {
    // This method adds robustness by trying multiple approaches
    // and includes safeguards for PUBG Mobile
    
    // Reset visibility state before attempting to attach
    _isVisible = NO;
    
    // If already attached to a layer, remove first to avoid duplicates
    // This can happen if visibility state gets out of sync
    @try {
        [_backgroundLayer removeFromSuperlayer];
    } @catch (NSException *exception) {
        NSLog(@"FPSIndicator: Exception removing existing layer (non-critical): %@", exception);
    }
    
    // First attempt: scene-based window management (iOS 13+)
    if (@available(iOS 13.0, *)) {
        if ([self attachToSceneWindow]) {
            return;
        }
    }
    
    // Second attempt: legacy key window approach
    if ([self attachToKeyWindow]) {
        return;
    }
    
    // Third attempt: find any suitable window
    if ([self attachToAnyWindow]) {
        return;
    }
    
    // Fourth attempt: use root view controller if available
    if ([self attachToRootViewController]) {
        return;
    }
    
    // Fifth attempt: create our own window as a last resort
    // Only for normal mode, as this could trigger anti-cheat in PUBG
    if ([self createAndAttachToNewWindow]) {
        return;
    }
    
    // If we get here, all attempts failed
    NSLog(@"FPSIndicator: All attachment methods failed");
}

#pragma mark - Window Attachment Methods

// Attempt to attach to scene window (iOS 13+)
- (BOOL)attachToSceneWindow {
    if (@available(iOS 13.0, *)) {
        @try {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow *window in scene.windows) {
                        if (!window.hidden && window.layer) {
                            [window.layer addSublayer:_backgroundLayer];
                            _isVisible = YES;
                            NSLog(@"FPSIndicator: Added overlay to scene window layer");
                            return YES;
                        }
                    }
                }
            }
        } @catch (NSException *exception) {
            NSLog(@"FPSIndicator: Exception attaching to scene window: %@", exception);
        }
    }
    return NO;
}

// Attempt to attach to key window
- (BOOL)attachToKeyWindow {
    @try {
        UIWindow *keyWindow = nil;
        
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        keyWindow = [UIApplication sharedApplication].keyWindow;
        #pragma clang diagnostic pop
        
        if (keyWindow && !keyWindow.hidden && keyWindow.layer) {
            [keyWindow.layer addSublayer:_backgroundLayer];
            _isVisible = YES;
            NSLog(@"FPSIndicator: Added overlay to key window layer");
            return YES;
        }
    } @catch (NSException *exception) {
        NSLog(@"FPSIndicator: Exception attaching to key window: %@", exception);
    }
    return NO;
}

// Attempt to attach to any window
- (BOOL)attachToAnyWindow {
    @try {
        NSArray *windows = nil;
        
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        windows = [UIApplication sharedApplication].windows;
        #pragma clang diagnostic pop
        
        for (UIWindow *window in windows) {
            if (!window.hidden && window.layer) {
                [window.layer addSublayer:_backgroundLayer];
                _isVisible = YES;
                NSLog(@"FPSIndicator: Added overlay to window from windows array");
                return YES;
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"FPSIndicator: Exception attaching to windows array: %@", exception);
    }
    return NO;
}

// Attempt to attach to root view controller
- (BOOL)attachToRootViewController {
    @try {
        UIViewController *rootVC = nil;
        
        // Try to get root view controller
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        #pragma clang diagnostic pop
        
        if (!rootVC) {
            NSArray *windows = nil;
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            windows = [UIApplication sharedApplication].windows;
            #pragma clang diagnostic pop
            
            for (UIWindow *window in windows) {
                if (window.rootViewController) {
                    rootVC = window.rootViewController;
                    break;
                }
            }
        }
        
        if (rootVC && rootVC.view && rootVC.view.layer) {
            [rootVC.view.layer addSublayer:_backgroundLayer];
            _isVisible = YES;
            NSLog(@"FPSIndicator: Added overlay to root view controller layer");
            return YES;
        }
    } @catch (NSException *exception) {
        NSLog(@"FPSIndicator: Exception attaching to root view controller: %@", exception);
    }
    return NO;
}

// Create a new window as a last resort
// Note: This method might trigger anti-cheat in PUBG Mobile
- (BOOL)createAndAttachToNewWindow {
    // Don't use this approach for PUBG Mobile
    NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;
    if ([bundleID hasPrefix:@"com.tencent.ig"] || 
        [bundleID hasPrefix:@"com.pubg."] || 
        [bundleID hasPrefix:@"com.tencent.tmgp.pubg"] ||
        [bundleID hasPrefix:@"com.rekoo.pubg"] ||
        [bundleID hasPrefix:@"com.vng.pubgmobile"]) {
        NSLog(@"FPSIndicator: Skipping custom window creation for PUBG Mobile");
        return NO;
    }
    
    @try {
        // Only create a new window as a last resort for non-PUBG apps
        // This is a private property just for this method
        static UIWindow *customWindow = nil;
        
        if (!customWindow) {
            CGRect screenBounds = [UIScreen mainScreen].bounds;
            
            if (@available(iOS 13.0, *)) {
                UIWindowScene *scene = nil;
                for (UIWindowScene *s in [UIApplication sharedApplication].connectedScenes) {
                    if (s.activationState == UISceneActivationStateForegroundActive) {
                        scene = s;
                        break;
                    }
                }
                
                if (scene) {
                    customWindow = [[UIWindow alloc] initWithWindowScene:scene];
                } else {
                    customWindow = [[UIWindow alloc] initWithFrame:screenBounds];
                }
            } else {
                customWindow = [[UIWindow alloc] initWithFrame:screenBounds];
            }
            
            // Make it completely transparent and non-interactive
            customWindow.windowLevel = UIWindowLevelStatusBar + 1;
            customWindow.backgroundColor = [UIColor clearColor];
            customWindow.userInteractionEnabled = NO;
            customWindow.hidden = NO;
        }
        
        if (customWindow && customWindow.layer) {
            [customWindow.layer addSublayer:_backgroundLayer];
            _isVisible = YES;
            NSLog(@"FPSIndicator: Created custom window and added overlay");
            return YES;
        }
    } @catch (NSException *exception) {
        NSLog(@"FPSIndicator: Exception creating custom window: %@", exception);
    }
    return NO;
}

- (void)updateWithFPS:(double)fps {
    // Ensure we're on the main thread
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateWithFPS:fps];
        });
        return;
    }
    
    // Format the FPS with one decimal place
    @try {
        NSString *fpsText = [NSString stringWithFormat:@"%.1f FPS", fps];
        _fpsTextLayer.string = fpsText;
        
        // Color coding based on performance
        if (fps >= 58) {
            _fpsTextLayer.foregroundColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.0 alpha:1.0].CGColor; // Green
        } else if (fps >= 45) {
            _fpsTextLayer.foregroundColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.0 alpha:1.0].CGColor; // Yellow
        } else if (fps >= 30) {
            _fpsTextLayer.foregroundColor = [UIColor colorWithRed:0.9 green:0.5 blue:0.0 alpha:1.0].CGColor; // Orange
        } else {
            _fpsTextLayer.foregroundColor = [UIColor colorWithRed:0.8 green:0.0 blue:0.0 alpha:1.0].CGColor; // Red
        }
        
        // Ensure the display updates
        [CATransaction begin];
        [CATransaction setDisableActions:YES]; // Disable animations for immediate update
        // Position updates should go here if needed
        [CATransaction commit];
    } @catch (NSException *exception) {
        NSLog(@"FPSIndicator: Exception updating FPS display: %@", exception);
    }
}

- (void)hide {
    // Ensure we're on the main thread
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hide];
        });
        return;
    }
    
    if (_isVisible) {
        @try {
            [_backgroundLayer removeFromSuperlayer];
            _isVisible = NO;
        } @catch (NSException *exception) {
            NSLog(@"FPSIndicator: Exception hiding overlay: %@", exception);
        }
    }
}

- (BOOL)isVisible {
    return _isVisible;
}

- (void)updatePosition:(CGPoint)newPosition {
    // Ensure we're on the main thread
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updatePosition:newPosition];
        });
        return;
    }
    
    if (_backgroundLayer) {
        @try {
            [CATransaction begin];
            [CATransaction setDisableActions:YES]; // Disable animations
            _backgroundLayer.position = newPosition;
            [CATransaction commit];
        } @catch (NSException *exception) {
            NSLog(@"FPSIndicator: Exception updating position: %@", exception);
        }
    }
}

// Add a method to make the overlay draggable
- (void)enableDragging {
    // This is for future implementation
    // Would require adding gesture recognition via a transparent UIView
    // or intercepting touch events from the main application
}

@end