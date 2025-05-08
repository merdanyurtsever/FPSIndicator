// FPSDisplay.h
#import <UIKit/UIKit.h>

/**
 * FPSDisplay - Simple, lightweight FPS display overlay
 * 
 * This class provides a draggable window that displays the current FPS
 * with proper iOS compatibility and scene support.
 */
@interface FPSDisplay : UIWindow

// Configuration properties
@property (nonatomic, assign) CGFloat fontSize;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic, assign) CGFloat backgroundAlpha;
@property (nonatomic, assign) BOOL colorCoding;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) CGPoint position;

// Display components
@property (nonatomic, strong) UILabel *fpsLabel;

// Core methods
- (void)updateWithFPS:(double)fps;
- (void)updatePosition;
- (void)setVisible:(BOOL)visible;

// iOS 13+ window scene support
- (void)setupWithWindowScene:(UIWindowScene *)scene;

// Screen recording notification handler
- (void)screenCaptureDidChange:(NSNotification *)notification;

// Singleton accessor
+ (instancetype)sharedInstance;

@end