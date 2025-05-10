#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

/**
 * FPSPUBGSupport - PUBG-specific optimizations and anti-cheat avoidance
 * 
 * This component provides specialized handling for PUBG Mobile,
 * with advanced techniques to avoid detection by the game's anti-cheat.
 */
@interface FPSPUBGSupport : NSObject

/**
 * @property stealth Mode level of stealth
 * 0 = Normal mode (standard hooks)
 * 1 = Medium stealth (delayed initialization, fewer hooks)
 * 2 = Maximum stealth (minimal footprint, Metal2-only)
 */
@property (nonatomic, assign) NSInteger stealthMode;

/**
 * @property useQuartzCoreDebug Whether to use the QuartzCore debug APIs
 * when available (requires jailbreak with appropriate entitlements)
 */
@property (nonatomic, assign) BOOL useQuartzCoreDebug;

/**
 * @property refreshRate How often to update the FPS counter (in Hz)
 */
@property (nonatomic, assign) CGFloat refreshRate;

/**
 * Initializes the PUBG Mobile support with appropriate hooks
 * and anti-detection techniques. Will automatically determine
 * the best method based on the device and game version.
 */
- (void)initialize;

/**
 * Starts FPS monitoring with the appropriate method
 * based on selected stealthMode and device capabilities
 */
- (void)startMonitoring;

/**
 * Stops FPS monitoring
 */
- (void)stopMonitoring;

/**
 * Gets the current FPS using whichever method is active
 * @return The current frames per second
 */
- (double)getCurrentFPS;

/**
 * Determines if the current app is PUBG Mobile
 * @return YES if current app is PUBG Mobile
 */
+ (BOOL)isPUBGMobile;

/**
 * Singleton accessor
 * @return The shared FPSPUBGSupport instance
 */
+ (instancetype)sharedInstance;

@end
