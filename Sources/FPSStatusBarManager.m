#import "FPSStatusBarManager.h"
#import <objc/runtime.h>

// Forward declarations for private classes
@interface _UIStatusBarStringView : UIView
@property (nonatomic, copy) NSString *text;
@end

// Internal iOS interfaces for fixed implementation
@implementation FPSStatusBarManager {
    UIView *_fpsStringView;
    UIView *_containerView;
    BOOL _isEnabled;
    BOOL _isSetup;
}

+ (instancetype)sharedInstance {
    static FPSStatusBarManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _isEnabled = YES;
        _isSetup = NO;
    }
    return self;
}

- (void)setup {
    if (_isSetup) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Try to find the status bar
        [self findAndInjectIntoStatusBar];
        
        // Also register for orientation changes to ensure the indicator stays visible
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(orientationDidChange:)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
        
        self->_isSetup = YES;
        
        NSLog(@"FPSIndicator: Status bar injection attempted");
    });
}

- (void)findAndInjectIntoStatusBar {
    // Try safer approach using rootViewController
    UIWindow *window = nil;
    
    // Find an active scene window
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                window = scene.windows.firstObject;
                break;
            }
        }
    }
    
    // Fallback to finding any window
    if (!window) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (!w.hidden && w.alpha > 0) {
                window = w;
                break;
            }
        }
        #pragma clang diagnostic pop
    }
    
    if (!window) {
        NSLog(@"FPSIndicator: Could not find any window");
        [self createFloatingIndicator];
        return;
    }
    
    // Try to find status bar in window's rootViewController
    UIViewController *rootVC = window.rootViewController;
    UIView *statusBar = nil;
    
    // Try to find the status bar view in the view hierarchy
    for (UIView *subview in rootVC.view.window.subviews) {
        NSString *className = NSStringFromClass([subview class]);
        if ([className containsString:@"StatusBar"] && 
            ![className containsString:@"Window"]) {
            statusBar = subview;
            break;
        }
    }
    
    if (!statusBar) {
        NSLog(@"FPSIndicator: Could not find status bar view");
        [self createFloatingIndicator];
        return;
    }
    
    // Create FPS label if needed
    if (!_fpsStringView) {
        _fpsStringView = [[UILabel alloc] init];
        ((UILabel *)_fpsStringView).text = @"-- FPS";
        ((UILabel *)_fpsStringView).textColor = [UIColor greenColor];
        ((UILabel *)_fpsStringView).font = [UIFont boldSystemFontOfSize:10];
        _fpsStringView.frame = CGRectMake(0, 0, 60, 20);
    }
    
    // Add to status bar
    [statusBar addSubview:_fpsStringView];
    
    // Position it to the right
    CGFloat xPos = statusBar.bounds.size.width - _fpsStringView.frame.size.width - 10;
    CGFloat yPos = (statusBar.bounds.size.height - _fpsStringView.frame.size.height) / 2.0;
    _fpsStringView.frame = CGRectMake(xPos, yPos, 
                                     _fpsStringView.frame.size.width, 
                                     _fpsStringView.frame.size.height);
    
    NSLog(@"FPSIndicator: Successfully added to status bar");
}

- (void)createFloatingIndicator {
    // Last resort: create a system-wide floating indicator that should override restrictions
    
    // Create a container view to hold the FPS
    _containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 60, 30)];
    _containerView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
    _containerView.layer.cornerRadius = 10;
    _containerView.clipsToBounds = YES;
    
    // Create label
    UILabel *label = [[UILabel alloc] initWithFrame:_containerView.bounds];
    label.text = @"-- FPS";
    label.textColor = [UIColor greenColor];
    label.font = [UIFont boldSystemFontOfSize:12];
    label.textAlignment = NSTextAlignmentCenter;
    [_containerView addSubview:label];
    _fpsStringView = label;
    
    // Position at top of screen
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    _containerView.frame = CGRectMake(screenBounds.size.width - 65, 40, 60, 30);
    
    // Find a window to attach to
    UIWindow *targetWindow = nil;
    
    // Try to find a suitable window using Scene API (iOS 13+)
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (!window.hidden) {
                        targetWindow = window;
                        break;
                    }
                }
                if (targetWindow) break;
            }
        }
    }
    
    // Fallback with proper deprecation handling
    if (!targetWindow) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (!window.hidden) {
                targetWindow = window;
                break;
            }
        }
        #pragma clang diagnostic pop
    }
    
    if (targetWindow) {
        [targetWindow addSubview:_containerView];
        _containerView.layer.zPosition = 9999;
        NSLog(@"FPSIndicator: Added floating indicator as last resort");
    }
}

- (void)updateWithFPS:(double)fps {
    if (!_isEnabled || !_fpsStringView) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self->_fpsStringView isKindOfClass:[UILabel class]]) {
            ((UILabel *)self->_fpsStringView).text = [NSString stringWithFormat:@"%.1f FPS", fps];
            
            // Color code based on performance
            UIColor *color;
            if (fps >= 50.0) {
                color = [UIColor greenColor];
            } else if (fps >= 30.0) {
                color = [UIColor yellowColor];
            } else {
                color = [UIColor redColor];
            }
            
            ((UILabel *)self->_fpsStringView).textColor = color;
        } else if ([self->_fpsStringView respondsToSelector:@selector(setText:)]) {
            // Handle case where we got a _UIStatusBarStringView
            [self->_fpsStringView performSelector:@selector(setText:) 
                                      withObject:[NSString stringWithFormat:@"%.1f FPS", fps]];
        }
    });
}

- (void)setEnabled:(BOOL)enabled {
    _isEnabled = enabled;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_fpsStringView) {
            self->_fpsStringView.hidden = !enabled;
        }
        if (self->_containerView) {
            self->_containerView.hidden = !enabled;
        }
    });
}

- (void)orientationDidChange:(NSNotification *)notification {
    // Reposition when orientation changes
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self findAndInjectIntoStatusBar];
    });
}

@end