// FPSDisplay.m
#import "FPSDisplay.h"
#import "FPSCounter.h"
#import <objc/message.h> // Adding this header for objc_msgSend

// Forward declaration of FPSPreferences (will implement later)
@interface FPSPreferences : NSObject
+ (instancetype)sharedPreferences;
- (void)setCustomPosition:(CGPoint)position;
- (void)savePreferences;
@end

@implementation FPSDisplay {
    CADisplayLink *_displayLink;
    UIPanGestureRecognizer *_panGesture;
    UIView *_containerView;
    BOOL _isScreenRecording;
}

+ (instancetype)sharedInstance {
    static FPSDisplay *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FPSDisplay alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        // Configure window properties
        self.windowLevel = UIWindowLevelStatusBar + 100;
        self.backgroundColor = [UIColor clearColor];
        
        // Set initial frame (size will be set by updatePosition)
        self.frame = CGRectMake(0, 0, 80, 30);
        
        // Create container view
        _containerView = [[UIView alloc] initWithFrame:self.bounds];
        _containerView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.7];
        _containerView.layer.cornerRadius = 5;
        _containerView.clipsToBounds = YES;
        [self addSubview:_containerView];
        
        // Create FPS label
        _fpsLabel = [[UILabel alloc] initWithFrame:_containerView.bounds];
        _fpsLabel.textAlignment = NSTextAlignmentCenter;
        _fpsLabel.textColor = [UIColor whiteColor];
        _fpsLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        [_containerView addSubview:_fpsLabel];
        
        // Default settings
        _textColor = [UIColor whiteColor];
        _backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.7];
        _backgroundAlpha = 0.7;
        _fontSize = 14;
        _colorCoding = YES;
        _position = CGPointMake(20, 40);
        _enabled = YES;
        
        // Add pan gesture for dragging
        _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [_containerView addGestureRecognizer:_panGesture];
        
        // Set up display link for updates (limited to 10Hz to save power)
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkUpdate)];
        if (@available(iOS 10.0, *)) {
            _displayLink.preferredFramesPerSecond = 10; // Update at 10Hz
        } else {
            // For older iOS versions
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            _displayLink.frameInterval = 6; // Roughly 10Hz (60/6)
            #pragma clang diagnostic pop
        }
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        
        // Update position to match screen bounds
        [self updatePosition];
        
        // Register for device orientation changes
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(orientationChanged:) 
                                                     name:UIDeviceOrientationDidChangeNotification 
                                                   object:nil];
    }
    return self;
}

- (void)updateWithFPS:(double)fps {
    // Format the FPS with one decimal place
    NSString *fpsText = [NSString stringWithFormat:@"%.1f FPS", fps];
    self.fpsLabel.text = fpsText;
    
    // Apply color coding if enabled
    if (_colorCoding) {
        if (fps >= 50) {
            self.fpsLabel.textColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.0 alpha:1.0]; // Green
        } else if (fps >= 30) {
            self.fpsLabel.textColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.0 alpha:1.0]; // Yellow
        } else {
            self.fpsLabel.textColor = [UIColor colorWithRed:0.9 green:0.0 blue:0.0 alpha:1.0]; // Red
        }
    } else {
        self.fpsLabel.textColor = _textColor;
    }
}

- (void)displayLinkUpdate {
    [self updateWithFPS:[[FPSCounter sharedInstance] currentFPS]];
}

- (void)updatePosition {
    // Apply current position
    CGFloat width = 80;  // Fixed width
    CGFloat height = 30; // Fixed height
    
    // Set frame size and position
    self.frame = CGRectMake(_position.x, _position.y, width, height);
    _containerView.frame = self.bounds;
    _fpsLabel.frame = _containerView.bounds;
    
    // Ensure the window stays within screen bounds
    CGRect bounds = [UIScreen mainScreen].bounds;
    CGRect frame = self.frame;
    
    if (frame.origin.x < 0) frame.origin.x = 0;
    if (frame.origin.y < 0) frame.origin.y = 0;
    if (frame.origin.x + frame.size.width > bounds.size.width) {
        frame.origin.x = bounds.size.width - frame.size.width;
    }
    if (frame.origin.y + frame.size.height > bounds.size.height) {
        frame.origin.y = bounds.size.height - frame.size.height;
    }
    
    if (!CGRectEqualToRect(self.frame, frame)) {
        self.frame = frame;
        _position = frame.origin;
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self];
    
    if (gesture.state == UIGestureRecognizerStateChanged) {
        _position.x += translation.x;
        _position.y += translation.y;
        [self updatePosition];
        [gesture setTranslation:CGPointZero inView:self];
    }
    
    if (gesture.state == UIGestureRecognizerStateEnded) {
        // Save the position
        Class prefsClass = NSClassFromString(@"FPSPreferences");
        if (prefsClass) {
            id preferences = [prefsClass sharedPreferences];
            if ([preferences respondsToSelector:@selector(setCustomPosition:)]) {
                [preferences setCustomPosition:_position];
                [preferences savePreferences];
            }
        }
    }
}

- (void)setVisible:(BOOL)visible {
    self.hidden = !visible;
}

- (void)orientationChanged:(NSNotification *)notification {
    [self updatePosition];
}

- (void)setupWithWindowScene:(UIWindowScene *)scene {
    if (@available(iOS 13.0, *)) {
        self.windowScene = scene;
        [self makeKeyAndVisible];
        [self updatePosition];
    }
}

- (void)screenCaptureDidChange:(NSNotification *)notification {
    if (@available(iOS 11.0, *)) {
        UIScreen *screen = [UIScreen mainScreen];
        _isScreenRecording = screen.isCaptured;
        
        // Check if we need to hide during screen recording
        Class prefsClass = NSClassFromString(@"FPSPreferences");
        if (prefsClass) {
            id preferences = [prefsClass sharedPreferences];
            if ([preferences respondsToSelector:@selector(enabled)]) {
                // Using a safer approach than direct objc_msgSend call
                BOOL enabled = NO;
                NSMethodSignature *signature = [preferences methodSignatureForSelector:@selector(enabled)];
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                [invocation setSelector:@selector(enabled)];
                [invocation setTarget:preferences];
                [invocation invoke];
                [invocation getReturnValue:&enabled];
                
                [self setVisible:enabled && !_isScreenRecording];
            }
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_displayLink invalidate];
    _displayLink = nil;
}

@end