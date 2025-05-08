#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 * FPSStatusBarManager
 * 
 * Injects FPS display directly into the status bar to bypass floating window restrictions.
 * This approach avoids the security restrictions that prevent floating windows.
 */
@interface FPSStatusBarManager : NSObject

/**
 * Shared instance accessor
 */
+ (instancetype)sharedInstance;

/**
 * Initialize the status bar FPS indicator
 */
- (void)setup;

/**
 * Update the displayed FPS value
 * @param fps Current FPS value to display
 */
- (void)updateWithFPS:(double)fps;

/**
 * Enable or disable the status bar indicator
 * @param enabled Whether the indicator should be enabled
 */
- (void)setEnabled:(BOOL)enabled;

@end