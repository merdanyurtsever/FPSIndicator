#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

/**
 * FPSAlternativeOverlay
 * 
 * An alternative implementation of the FPS indicator using CALayers
 * directly attached to window layers. This approach might work better
 * with rootless jailbreak restrictions than UIWindow-based methods.
 */
@interface FPSAlternativeOverlay : NSObject

/**
 * Shared instance accessor
 * @return The shared FPSAlternativeOverlay instance
 */
+ (instancetype)sharedInstance;

/**
 * Show the overlay with the given FPS value
 * @param fps The FPS value to display
 */
- (void)showWithFPS:(double)fps;

/**
 * Hide the overlay
 */
- (void)hide;

/**
 * Check if the overlay is currently visible
 * @return YES if the overlay is visible
 */
- (BOOL)isVisible;

@end