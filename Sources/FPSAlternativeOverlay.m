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
    if (!_isVisible) {
        // Try to find a suitable window to attach our layer
        UIWindow *targetWindow = nil;
        
        // Modern approach using scene-based window management for iOS 13+
        if (@available(iOS 13.0, *)) {
            // Get the active scene
            UIWindowScene *activeScene = nil;
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    activeScene = scene;
                    break;
                }
            }
            
            if (activeScene) {
                // Find the first non-hidden window in the active scene
                NSArray<UIWindow *> *windows = activeScene.windows;
                for (UIWindow *window in windows) {
                    if (!window.hidden) {
                        targetWindow = window;
                        break;
                    }
                }
            }
        } 
        
        // Legacy approach - use with iOS version check to avoid warnings
        if (!targetWindow) {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            if (@available(iOS 13.0, *)) {
                // Already tried the scene-based approach
            } else {
                targetWindow = [UIApplication sharedApplication].keyWindow;
                
                if (!targetWindow && [UIApplication sharedApplication].windows.count > 0) {
                    targetWindow = [UIApplication sharedApplication].windows.firstObject;
                }
            }
            #pragma clang diagnostic pop
        }
        
        // Add our layer to the target window or try alternative approaches
        if (targetWindow) {
            [targetWindow.layer addSublayer:_backgroundLayer];
            _isVisible = YES;
            NSLog(@"FPSIndicator: Added alternative overlay to window layer");
        } else {
            // If we couldn't find a suitable window, try to attach to a top-level layer
            // This is especially useful for games like PUBG that might use custom window hierarchies
            NSLog(@"FPSIndicator: No suitable window found, trying alternative attachment");
            
            // Find a top-level CALayer that might work
            CALayer *rootLayer = nil;
            
            // Try to find any UIWindow's layer that might be accessible
            if (@available(iOS 15.0, *)) {
                // Use window scene approach for iOS 15+
                NSArray<UIScene *> *scenes = UIApplication.sharedApplication.connectedScenes.allObjects;
                for (UIScene *scene in scenes) {
                    if ([scene isKindOfClass:[UIWindowScene class]]) {
                        UIWindowScene *windowScene = (UIWindowScene *)scene;
                        NSArray<UIWindow *> *windows = windowScene.windows;
                        for (UIWindow *window in windows) {
                            if (window.layer) {
                                rootLayer = window.layer;
                                break;
                            }
                        }
                        if (rootLayer) break;
                    }
                }
            } else {
                // Use deprecated approach for older iOS versions
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Wdeprecated-declarations"
                for (UIWindow *window in [UIApplication sharedApplication].windows) {
                    if (window.layer) {
                        rootLayer = window.layer;
                        break;
                    }
                }
                #pragma clang diagnostic pop
            }
            
            if (rootLayer) {
                [rootLayer addSublayer:_backgroundLayer];
                _isVisible = YES;
                NSLog(@"FPSIndicator: Added alternative overlay to application root layer");
            } else {
                NSLog(@"FPSIndicator: Could not find any layer to attach the overlay");
            }
        }
    }
    
    // Update FPS value with color coding
    [self updateWithFPS:fps];
}

- (void)updateWithFPS:(double)fps {
    // Format the FPS with one decimal place
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
}

- (void)hide {
    if (_isVisible) {
        [_backgroundLayer removeFromSuperlayer];
        _isVisible = NO;
    }
}

- (BOOL)isVisible {
    return _isVisible;
}

- (void)updatePosition:(CGPoint)newPosition {
    if (_backgroundLayer) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES]; // Disable animations
        _backgroundLayer.position = newPosition;
        [CATransaction commit];
    }
}

// Add a method to make the overlay draggable
- (void)enableDragging {
    // This is for future implementation
    // Would require adding gesture recognition via a transparent UIView
    // or intercepting touch events from the main application
}

@end