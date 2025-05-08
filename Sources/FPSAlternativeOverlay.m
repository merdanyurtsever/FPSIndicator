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
            // Last resort: try to get the root layer using private API
            @try {
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Wundeclared-selector"
                UIScreen *mainScreen = [UIScreen mainScreen];
                if ([mainScreen respondsToSelector:@selector(_layers)]) {
                    id layers = [mainScreen performSelector:@selector(_layers)];
                    if ([layers isKindOfClass:[CALayer class]]) {
                        [(CALayer *)layers addSublayer:_backgroundLayer];
                        _isVisible = YES;
                        NSLog(@"FPSIndicator: Added alternative overlay to screen root layer");
                    }
                }
                #pragma clang diagnostic pop
            } @catch (NSException *exception) {
                NSLog(@"FPSIndicator: Failed to add overlay layer: %@", exception);
            }
        }
    }
    
    // Update the FPS text
    _fpsTextLayer.string = [NSString stringWithFormat:@"%.1f FPS", fps];
    
    // Color based on performance
    if (fps >= 50.0) {
        _fpsTextLayer.foregroundColor = [UIColor greenColor].CGColor;
    } else if (fps >= 30.0) {
        _fpsTextLayer.foregroundColor = [UIColor yellowColor].CGColor;
    } else {
        _fpsTextLayer.foregroundColor = [UIColor redColor].CGColor;
    }
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

@end